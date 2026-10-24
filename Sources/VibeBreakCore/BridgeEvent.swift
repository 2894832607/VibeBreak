import Foundation

public enum BridgeEventKind: String, Codable, Sendable {
    case started
    case finished
    case interrupted
}

public struct BridgeEventRecord: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var source: String
    public var event: BridgeEventKind
    public var threadID: String
    public var taskID: String
    public var reason: TaskCompletionReason?
    public var timestamp: String?

    public init(
        version: Int = currentVersion,
        source: String,
        event: BridgeEventKind,
        threadID: String,
        taskID: String,
        reason: TaskCompletionReason? = nil,
        timestamp: String? = nil
    ) {
        self.version = version
        self.source = source
        self.event = event
        self.threadID = threadID
        self.taskID = taskID
        self.reason = reason
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case source
        case event
        case threadID = "thread_id"
        case taskID = "task_id"
        case reason
        case timestamp
    }
}

public enum BridgeEventError: LocalizedError, Equatable {
    case invalidJSON
    case unsupportedVersion(Int)
    case emptySource
    case emptyThreadID
    case emptyTaskID

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Bridge 事件不是有效 JSON"
        case .unsupportedVersion(let version):
            return "Bridge 事件版本 \(version) 不受支持"
        case .emptySource:
            return "Bridge 事件缺少 source"
        case .emptyThreadID:
            return "Bridge 事件缺少 thread_id"
        case .emptyTaskID:
            return "Bridge 事件缺少 task_id"
        }
    }
}

public enum BridgeEventParser {
    public static func decode(line: String) throws -> BridgeEventRecord {
        guard let data = line.data(using: .utf8) else {
            throw BridgeEventError.invalidJSON
        }
        let decoder = JSONDecoder()
        let record: BridgeEventRecord
        do {
            record = try decoder.decode(BridgeEventRecord.self, from: data)
        } catch {
            throw BridgeEventError.invalidJSON
        }
        try validate(record)
        return record
    }

    public static func lifecycleEvent(
        from record: BridgeEventRecord,
        acceptedSourceID: String
    ) -> LifecycleEvent? {
        guard record.source == acceptedSourceID else {
            return nil
        }
        let task = AgentTask(
            sourceID: record.source,
            threadID: record.threadID,
            taskID: record.taskID
        )
        switch record.event {
        case .started:
            return .started(task)
        case .finished:
            return .finished(task, reason: record.reason ?? .completed)
        case .interrupted:
            return .finished(task, reason: .interrupted)
        }
    }

    public static func encodeLine(_ record: BridgeEventRecord) throws -> Data {
        try validate(record)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    private static func validate(_ record: BridgeEventRecord) throws {
        guard record.version == BridgeEventRecord.currentVersion else {
            throw BridgeEventError.unsupportedVersion(record.version)
        }
        guard !record.source.isEmpty else {
            throw BridgeEventError.emptySource
        }
        guard !record.threadID.isEmpty else {
            throw BridgeEventError.emptyThreadID
        }
        guard !record.taskID.isEmpty else {
            throw BridgeEventError.emptyTaskID
        }
    }
}
