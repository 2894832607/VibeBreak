import Foundation
import SQLite3

public final class CodexSQLiteEventSource: AgentEventSource {
    public let id = "codex-desktop"
    public var onEvent: ((LifecycleEvent) -> Void)?
    public var onHealthChange: ((SourceHealth) -> Void)?
    public var onStateInvalidated: (() -> Void)?

    private let databaseURL: URL
    private let pollInterval: TimeInterval
    private let queue = DispatchQueue(label: "app.vibebreak.codex-source")

    private var database: OpaquePointer?
    private var timer: DispatchSourceTimer?
    private var cursor: Int64 = 0
    private var cursorInitialized = false
    private var activeTasksByThread: [String: Set<AgentTask>] = [:]
    private var health: SourceHealth = .stopped
    private var nextConnectionAttempt = Date.distantPast

    public init(databaseURL: URL, pollInterval: TimeInterval = 0.1) {
        self.databaseURL = databaseURL
        self.pollInterval = pollInterval
    }

    deinit {
        closeDatabase()
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            self.updateHealth(.connecting)
            self.connect()

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(
                deadline: .now() + self.pollInterval,
                repeating: self.pollInterval,
                leeway: .milliseconds(20)
            )
            timer.setEventHandler { [weak self] in
                self?.poll()
            }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            closeDatabase()
            activeTasksByThread.removeAll()
            cursor = 0
            cursorInitialized = false
            updateHealth(.stopped)
        }
    }

    private func poll() {
        if database == nil {
            guard Date() >= nextConnectionAttempt else { return }
            connect()
            return
        }
        drainNewRows()
    }

    private func connect() {
        closeDatabase()
        nextConnectionAttempt = Date().addingTimeInterval(2)

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }
            updateHealth(.failed("Codex 日志数据库不可读"))
            return
        }

        sqlite3_busy_timeout(handle, 200)
        database = handle

        guard validateSchema() else {
            closeDatabase()
            updateHealth(.incompatible("Codex 日志结构不兼容"))
            return
        }

        guard let maximumID = maximumRowID() else {
            closeDatabase()
            updateHealth(.failed("无法读取 Codex 日志游标"))
            return
        }

        if !cursorInitialized {
            cursor = maximumID
            cursorInitialized = true
        } else if maximumID < cursor {
            invalidateState(at: maximumID)
        }
        updateHealth(.monitoring)
    }

    private func closeDatabase() {
        if let database {
            sqlite3_close(database)
            self.database = nil
        }
    }

    private func validateSchema() -> Bool {
        guard let database else { return false }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(
            database,
            "PRAGMA table_info(logs);",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            return false
        }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            columns.insert(columnText(statement, index: 1))
        }
        return ["id", "target", "thread_id", "feedback_log_body"].allSatisfy {
            columns.contains($0)
        }
    }

    private func maximumRowID() -> Int64? {
        guard let database else { return nil }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(
            database,
            "SELECT COALESCE(MAX(id), 0) FROM logs;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            return nil
        }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(statement, 0)
    }

    private func drainNewRows() {
        guard let database else { return }
        guard let upperBound = maximumRowID() else {
            connectionFailed("无法读取 Codex 日志上界")
            return
        }
        if upperBound < cursor {
            invalidateState(at: upperBound)
            return
        }
        guard upperBound > cursor else {
            return
        }

        let placeholders = CodexLogParser.monitoredTargets
            .map { "'\($0)'" }
            .joined(separator: ",")
        let sql = """
        SELECT id, target, thread_id, feedback_log_body
        FROM logs
        WHERE id > ?1
          AND id <= ?2
          AND target IN (\(placeholders))
        ORDER BY id ASC;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            connectionFailed("Codex 日志查询准备失败")
            return
        }
        sqlite3_bind_int64(statement, 1, cursor)
        sqlite3_bind_int64(statement, 2, upperBound)

        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                let record = CodexLogRecord(
                    rowID: sqlite3_column_int64(statement, 0),
                    target: columnText(statement, index: 1),
                    threadID: columnText(statement, index: 2),
                    body: columnText(statement, index: 3)
                )
                if let signal = CodexLogParser.parse(record) {
                    handle(signal)
                }

            case SQLITE_DONE:
                cursor = upperBound
                return

            default:
                connectionFailed("Codex 日志查询中断")
                return
            }
        }
    }

    private func handle(_ signal: CodexLogSignal) {
        switch signal {
        case .started(let threadID, let taskID):
            let task = AgentTask(sourceID: id, threadID: threadID, taskID: taskID)
            activeTasksByThread[threadID, default: []].insert(task)
            onEvent?(.started(task))

        case .completed(let threadID, let taskID):
            let task = AgentTask(sourceID: id, threadID: threadID, taskID: taskID)
            activeTasksByThread[threadID]?.remove(task)
            if activeTasksByThread[threadID]?.isEmpty == true {
                activeTasksByThread[threadID] = nil
            }
            onEvent?(.finished(task, reason: .completed))

        case .interrupted(let threadID):
            guard let tasks = activeTasksByThread.removeValue(forKey: threadID) else {
                return
            }
            for task in tasks.sorted(by: { $0.taskID < $1.taskID }) {
                onEvent?(.finished(task, reason: .interrupted))
            }
        }
    }

    private func invalidateState(at maximumID: Int64) {
        cursor = maximumID
        activeTasksByThread.removeAll()
        onStateInvalidated?()
    }

    private func connectionFailed(_ message: String) {
        closeDatabase()
        updateHealth(.failed(message))
    }

    private func updateHealth(_ newValue: SourceHealth) {
        guard health != newValue else { return }
        health = newValue
        onHealthChange?(newValue)
    }

    private func columnText(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }
}
