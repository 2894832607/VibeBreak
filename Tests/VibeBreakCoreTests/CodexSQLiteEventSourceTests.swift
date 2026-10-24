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

    @Test(.timeLimit(.minutes(1)))
    func interruptFinishesEveryStartedTaskInSameThread() async throws {
        let url = temporaryDatabaseURL()
        var writer: OpaquePointer?
        try #require(sqlite3_open(url.path, &writer) == SQLITE_OK)
        defer {
            sqlite3_close(writer)
            try? FileManager.default.removeItem(at: url)
        }
        try execute("""
            CREATE TABLE logs (
                id INTEGER PRIMARY KEY, target TEXT, thread_id TEXT,
                feedback_log_body TEXT
            );
            """, on: writer)
        let source = CodexSQLiteEventSource(databaseURL: url, pollInterval: 0.01)
        defer { source.stop() }
        let lock = NSLock()
        var monitoring = false
        var state = TaskStateMachine()
        var events: [LifecycleEvent] = []
        source.onHealthChange = { health in
            lock.withLock { monitoring = health == .monitoring }
        }
        source.onEvent = { event in
            lock.withLock {
                state.apply(event)
                events.append(event)
            }
        }
        source.start()
        try await waitUntil(timeout: 1) { lock.withLock { monitoring } }
        try #require(lock.withLock { monitoring })
        for id in ["one", "two"] {
            try insert(
                target: CodexLogParser.handlersTarget, threadID: "thread",
                body: "Submission { id: \"\(id)\", op: UserInput }", on: writer
            )
        }
        try insert(
            target: CodexLogParser.sessionTarget, threadID: "thread",
            body: "interrupt received: abort current task", on: writer
        )
        try await waitUntil(timeout: 1) {
            lock.withLock { events.count >= 4 }
        }
        #expect(lock.withLock { state.activeCount } == 0)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func temporaryDisconnectPreservesTasksAndCursorRewindInvalidates(
        rewindOnReconnect: Bool
    ) async throws {
        let url = temporaryDatabaseURL()
        var writer: OpaquePointer?
        try #require(sqlite3_open(url.path, &writer) == SQLITE_OK)
        sqlite3_busy_timeout(writer, 1000)
        defer {
            sqlite3_close(writer)
            try? FileManager.default.removeItem(at: url)
        }
        try execute("""
            PRAGMA journal_mode=WAL;
            CREATE TABLE logs (
                id INTEGER PRIMARY KEY, target TEXT, thread_id TEXT,
                feedback_log_body TEXT
            );
            """, on: writer)
        let source = CodexSQLiteEventSource(databaseURL: url, pollInterval: 0.01)
        defer { source.stop() }
        let lock = NSLock()
        var health: SourceHealth = .stopped
        var events: [LifecycleEvent] = []
        var invalidations = 0
        source.onHealthChange = { value in lock.withLock { health = value } }
        source.onEvent = { event in lock.withLock { events.append(event) } }
        source.onStateInvalidated = { lock.withLock { invalidations += 1 } }
        source.start()
        try await waitUntil(timeout: 1) { lock.withLock { health == .monitoring } }
        try #require(lock.withLock { health == .monitoring })
        try insert(
            target: CodexLogParser.handlersTarget, threadID: "thread",
            body: "Submission { id: \"one\", op: UserInput }", on: writer
        )
        try await waitUntil(timeout: 1) { lock.withLock { events.count == 1 } }
        try #require(lock.withLock { events.count == 1 })
        // Make polling fail without losing rows or lowering the cursor.
        try execute("ALTER TABLE logs RENAME TO saved_logs;", on: writer)
        try await waitUntil(timeout: 1) {
            lock.withLock { if case .failed = health { return true }; return false }
        }
        try #require(lock.withLock { if case .failed = health { return true }; return false })
        #expect(lock.withLock { invalidations } == 0)
        try execute("ALTER TABLE saved_logs RENAME TO logs;", on: writer)
        try await waitUntil(timeout: 4) { lock.withLock { health == .monitoring } }
        try #require(lock.withLock { health == .monitoring })
        try insert(
            target: CodexLogParser.sessionTarget, threadID: "thread",
            body: "interrupt received: abort current task", on: writer
        )
        try await waitUntil(timeout: 1) { lock.withLock { events.count == 2 } }
        #expect(lock.withLock { events.last } == .finished(
            AgentTask(sourceID: source.id, threadID: "thread", taskID: "one"),
            reason: .interrupted
        ))
        try insert(
            target: CodexLogParser.handlersTarget, threadID: "thread",
            body: "Submission { id: \"two\", op: UserInput }", on: writer
        )
        try await waitUntil(timeout: 1) { lock.withLock { events.count == 3 } }
        try #require(lock.withLock { events.count == 3 })
        if rewindOnReconnect {
            try execute("ALTER TABLE logs RENAME TO saved_logs;", on: writer)
            try await waitUntil(timeout: 1) {
                lock.withLock { if case .failed = health { return true }; return false }
            }
            try #require(lock.withLock { if case .failed = health { return true }; return false })
            try execute("DELETE FROM saved_logs; ALTER TABLE saved_logs RENAME TO logs;", on: writer)
        } else {
            try execute("DELETE FROM logs;", on: writer)
        }
        try await waitUntil(timeout: 4) { lock.withLock { invalidations == 1 } }
        #expect(lock.withLock { invalidations } == 1)
        #expect(lock.withLock { events.count } == 3)
        try insert(
            target: CodexLogParser.sessionTarget, threadID: "thread",
            body: "interrupt received: abort current task", on: writer
        )
        try insert(
            target: CodexLogParser.handlersTarget, threadID: "new-thread",
            body: "Submission { id: \"three\", op: UserInput }", on: writer
        )
        try await waitUntil(timeout: 1) { lock.withLock { events.count == 4 } }
        #expect(lock.withLock { events.last } == .started(
            AgentTask(sourceID: source.id, threadID: "new-thread", taskID: "three")
        ))
        #expect(lock.withLock { invalidations } == 1)
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
            throw NSError(
                domain: "CodexSQLiteEventSourceTests", code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
            )
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
