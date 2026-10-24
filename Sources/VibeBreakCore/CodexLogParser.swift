import Foundation

public struct CodexLogRecord: Equatable, Sendable {
    public let rowID: Int64
    public let target: String
    public let threadID: String
    public let body: String

    public init(rowID: Int64, target: String, threadID: String, body: String) {
        self.rowID = rowID
        self.target = target
        self.threadID = threadID
        self.body = body
    }
}

public enum CodexLogSignal: Equatable, Sendable {
    case started(threadID: String, taskID: String)
    case completed(threadID: String, taskID: String)
    case interrupted(threadID: String)
}

public enum CodexLogParser {
    public static let handlersTarget = "codex_core::session::handlers"
    public static let turnTarget = "codex_core::session::turn"
    public static let sessionTarget = "codex_core::session"

    public static let monitoredTargets = [
        handlersTarget,
        turnTarget,
        sessionTarget,
    ]

    public static func parse(_ record: CodexLogRecord) -> CodexLogSignal? {
        switch record.target {
        case handlersTarget:
            guard record.body.contains("op: UserInput") else { return nil }
            guard let taskID = value(
                in: record.body,
                after: "Submission { id: \"",
                until: "\""
            ) else {
                return nil
            }
            return .started(threadID: record.threadID, taskID: taskID)

        case turnTarget:
            guard field(named: "needs_follow_up", in: record.body) == "false" else {
                return nil
            }
            guard let taskID = field(named: "turn_id", in: record.body) else {
                return nil
            }
            return .completed(threadID: record.threadID, taskID: taskID)

        case sessionTarget:
            guard record.body.contains("interrupt received: abort current task") else {
                return nil
            }
            return .interrupted(threadID: record.threadID)

        default:
            return nil
        }
    }

    private static func value(
        in body: String,
        after prefix: String,
        until terminator: String
    ) -> String? {
        guard let start = body.range(of: prefix) else { return nil }
        let remainder = body[start.upperBound...]
        guard let end = remainder.range(of: terminator) else { return nil }
        let token = remainder[..<end.lowerBound]
        return token.isEmpty ? nil : String(token)
    }

    private static func field(named name: String, in body: String) -> String? {
        let prefix = "\(name)="
        for token in body.split(whereSeparator: \.isWhitespace) {
            guard token.hasPrefix(prefix) else { continue }
            let value = token.dropFirst(prefix.count)
            return value.isEmpty ? nil : String(value)
        }
        return nil
    }
}
