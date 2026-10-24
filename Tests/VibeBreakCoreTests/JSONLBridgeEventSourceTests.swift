import Foundation
import Testing
@testable import VibeBreakCore

struct JSONLBridgeEventSourceTests {
    @Test(.timeLimit(.minutes(1)))
    func waitsForCompleteLineBeforeEmitting() async throws {
        let context = try TestContext()
        defer { context.stopAndCleanUp() }
        let source = context.source
        let task = AgentTask(
            sourceID: AgentSourceID.cursor.rawValue,
            threadID: "thread-1",
            taskID: "task-1"
        )
        let line = try BridgeEventParser.encodeLine(
            BridgeEventRecord(
                source: task.sourceID,
                event: .started,
                threadID: task.threadID,
                taskID: task.taskID
            )
        )
        let splitIndex = line.count / 2

        source.start()
        try await context.waitForMonitoring()
        try context.append(line.prefix(splitIndex))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(context.events.isEmpty)

        try context.append(line.suffix(from: splitIndex))
        try await context.waitUntil { context.events.count == 1 }

        #expect(context.events == [.started(task)])
    }

    @Test(.timeLimit(.minutes(1)))
    func reportsInvalidLineThenRecoversOnValidEvent() async throws {
        let context = try TestContext()
        defer { context.stopAndCleanUp() }

        context.source.start()
        try await context.waitForMonitoring()
        try context.append(Data("not-json\n".utf8))
        try await context.waitUntil {
            context.healthValues.contains {
                if case .failed = $0 { return true }
                return false
            }
        }

        let task = AgentTask(
            sourceID: AgentSourceID.cursor.rawValue,
            threadID: "thread-2",
            taskID: "task-2"
        )
        try context.append(
            BridgeEventParser.encodeLine(
                BridgeEventRecord(
                    source: task.sourceID,
                    event: .started,
                    threadID: task.threadID,
                    taskID: task.taskID
                )
            )
        )
        try await context.waitUntil {
            context.events == [.started(task)]
                && context.healthValues.last == .monitoring
        }
        #expect(context.invalidationCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func reportsFileTruncation() async throws {
        let context = try TestContext()
        defer { context.stopAndCleanUp() }

        context.source.start()
        try await context.waitForMonitoring()
        try context.append(Data("ignored historical bytes\n".utf8))
        try await Task.sleep(nanoseconds: 30_000_000)
        try FileHandle(forWritingTo: context.fileURL).truncate(atOffset: 0)

        try await context.waitUntil {
            context.invalidationCount == 1
        }
        #expect(context.healthValues.last == .monitoring)
    }
}

private final class TestContext: @unchecked Sendable {
    let directoryURL: URL
    let fileURL: URL
    let source: JSONLBridgeEventSource

    private let lock = NSLock()
    private var storedEvents: [LifecycleEvent] = []
    private var storedHealthValues: [SourceHealth] = []
    private var storedInvalidationCount = 0

    var invalidationCount: Int {
        lock.withLock { storedInvalidationCount }
    }

    var events: [LifecycleEvent] {
        lock.withLock { storedEvents }
    }

    var healthValues: [SourceHealth] {
        lock.withLock { storedHealthValues }
    }

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("events.jsonl")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: fileURL.path,
            contents: nil
        )
        source = JSONLBridgeEventSource(
            id: AgentSourceID.cursor.rawValue,
            fileURL: fileURL,
            pollInterval: 0.01
        )
        source.onEvent = { [weak self] event in
            self?.lock.withLock {
                self?.storedEvents.append(event)
            }
        }
        source.onHealthChange = { [weak self] health in
            self?.lock.withLock {
                self?.storedHealthValues.append(health)
            }
        }
        source.onStateInvalidated = { [weak self] in
            self?.lock.withLock {
                self?.storedInvalidationCount += 1
            }
        }
    }

    func append<D: DataProtocol>(_ data: D) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(data))
    }

    func waitForMonitoring() async throws {
        try await waitUntil {
            self.healthValues.last == .monitoring
        }
    }

    func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @Sendable () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(condition())
    }

    func stopAndCleanUp() {
        source.stop()
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
