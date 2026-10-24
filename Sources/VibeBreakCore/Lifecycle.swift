import Foundation

public struct AgentTask: Hashable, Sendable {
    public let sourceID: String
    public let threadID: String
    public let taskID: String

    public init(sourceID: String, threadID: String, taskID: String) {
        self.sourceID = sourceID
        self.threadID = threadID
        self.taskID = taskID
    }
}

public enum TaskCompletionReason: String, Codable, Equatable, Sendable {
    case completed
    case interrupted
    case failed
}

public enum LifecycleEvent: Equatable, Sendable {
    case started(AgentTask)
    case finished(AgentTask, reason: TaskCompletionReason)

    public var task: AgentTask {
        switch self {
        case .started(let task), .finished(let task, _):
            return task
        }
    }
}

public enum SourceHealth: Equatable, Sendable {
    case stopped
    case connecting
    case monitoring
    case incompatible(String)
    case failed(String)

    public var isMonitoring: Bool {
        self == .monitoring
    }
}

public protocol AgentEventSource: AnyObject {
    var id: String { get }
    var onEvent: ((LifecycleEvent) -> Void)? { get set }
    var onHealthChange: ((SourceHealth) -> Void)? { get set }

    func start()
    func stop()
}
