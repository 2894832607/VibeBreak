import Foundation

public enum TaskTransition: Equatable, Sendable {
    case becameActive
    case activeCountChanged
    case becameIdle
    case ignored
}

public struct TaskStateMachine: Sendable {
    public private(set) var activeTasks: Set<AgentTask> = []

    public init() {}

    public var activeCount: Int {
        activeTasks.count
    }

    @discardableResult
    public mutating func apply(_ event: LifecycleEvent) -> TaskTransition {
        switch event {
        case .started(let task):
            let wasIdle = activeTasks.isEmpty
            guard activeTasks.insert(task).inserted else { return .ignored }
            return wasIdle ? .becameActive : .activeCountChanged

        case .finished(let task, _):
            guard activeTasks.remove(task) != nil else { return .ignored }
            return activeTasks.isEmpty ? .becameIdle : .activeCountChanged
        }
    }

    public mutating func reset() {
        activeTasks.removeAll()
    }
}
