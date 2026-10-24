import Foundation
import SQLite3
import Testing
@testable import VibeBreakCore

struct CodexSQLiteEventSourceTests {
    @Test(.timeLimit(.minutes(1)))
    func streamsExplicitStartAndCompletionFromWALDatabase() async throws {
        let databaseURL = temporaryDatabaseURL()
        var writer: OpaquePointer?
        try #require(sqlite3_open(databaseURL.path, &writer) == SQLITE_OK)
        defer {
            sqlite3_close(writer)
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: databaseURL.path + "-wal")
            )
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: databaseURL.path + "-shm")
            )
        }

        try execute(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                target TEXT NOT NULL,
                thread_id TEXT,
                feedback_log_body TEXT
            );
            """,
            on: writer
        )

        let source = CodexSQLiteEventSource(
            databaseURL: databaseURL,
            pollInterval: 0.01
        )
        var events: [LifecycleEvent] = []
        let lock = NSLock()
        var inserted = false

        source.onHealthChange = { health in
            guard health == .monitoring else { return }
            lock.lock()
            defer { lock.unlock() }
            guard !inserted else { return }
            inserted = true

            try? self.insert(
                target: CodexLogParser.handlersTarget,
                threadID: "thread-1",
                body: """
                Submission sub=Submission { id: "task-1", op: UserInput { items: [] } }
                """,
                on: writer
            )
            try? self.insert(
                target: CodexLogParser.turnTarget,
                threadID: "thread-1",
                body: "post sampling token usage turn_id=task-1 needs_follow_up=false ",
                on: writer
            )
        }
        source.onEvent = { event in
            lock.lock()
            events.append(event)
            lock.unlock()
        }

        source.start()
        try await waitUntil(timeout: 2) {
            lock.withLock { events.count == 2 }
        }
        source.stop()

        let receivedEvents = lock.withLock { events }
        #expect(
            receivedEvents == [
                .started(
                    AgentTask(
                        sourceID: "codex-desktop",
                        threadID: "thread-1",
                        taskID: "task-1"
                    )
                ),
                .finished(
                    AgentTask(
                        sourceID: "codex-desktop",
                        threadID: "thread-1",
                        taskID: "task-1"
                    ),
                    reason: .completed
                ),
            ]
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func rejectsIncompatibleSchema() async throws {
        let databaseURL = temporaryDatabaseURL()
        var writer: OpaquePointer?
        try #require(sqlite3_open(databaseURL.path, &writer) == SQLITE_OK)
        try execute("CREATE TABLE logs (id INTEGER PRIMARY KEY);", on: writer)
        sqlite3_close(writer)
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let source = CodexSQLiteEventSource(
            databaseURL: databaseURL,
            pollInterval: 0.01
        )
        let lock = NSLock()
        var didReportIncompatible = false
        source.onHealthChange = { health in
            if case .incompatible = health {
                lock.withLock {
                    didReportIncompatible = true
                }
            }
        }

        source.start()
        try await waitUntil(timeout: 1) {
            lock.withLock { didReportIncompatible }
        }
        source.stop()
        #expect(lock.withLock { didReportIncompatible })
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeBreak-\(UUID().uuidString).sqlite")
    }

    private func execute(_ sql: String, on database: OpaquePointer?) throws {
        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &error)
        defer { sqlite3_free(error) }
        if result != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "unknown SQLite error"
            throw NSError(
                domain: "CodexSQLiteEventSourceTests",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func insert(
        target: String,
        threadID: String,
        body: String,
        on database: OpaquePointer?
    ) throws {
        let sql = """
        INSERT INTO logs (target, thread_id, feedback_log_body)
        VALUES (?1, ?2, ?3);
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "CodexSQLiteEventSourceTests", code: 1)
        }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, target, -1, transient)
        sqlite3_bind_text(statement, 2, threadID, -1, transient)
        sqlite3_bind_text(statement, 3, body, -1, transient)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NSError(domain: "CodexSQLiteEventSourceTests", code: 2)
        }
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
