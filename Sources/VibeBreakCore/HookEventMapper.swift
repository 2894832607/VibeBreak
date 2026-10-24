import Foundation

public struct HookEventPayload: Decodable, Equatable, Sendable {
    public let hookEventName: String
    public let sessionID: String?
    public let conversationID: String?
    public let generationID: String?
    public let status: String?

    private enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionID = "session_id"
        case conversationID = "conversation_id"
        case generationID = "generation_id"
        case status
    }
}

public enum HookLifecycleSignal: Equatable, Sendable {
    case started(threadID: String, taskID: String?)
    case finished(
        threadID: String,
        taskID: String?,
        reason: TaskCompletionReason
    )
}

public enum HookEventMappingError: LocalizedError, Equatable {
    case unsupportedSource(String)
    case unsupportedStatus(String)
    case missingField(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource(let sourceID):
            return "Hook source \(sourceID) is not supported"
        case .unsupportedStatus(let status):
            return "Hook completion status \(status) is not supported"
        case .missingField(let field):
            return "Hook payload is missing \(field)"
        }
    }
}

public enum HookEventMapper {
    public static func decode(data: Data) throws -> HookEventPayload {
        try JSONDecoder().decode(HookEventPayload.self, from: data)
    }

    public static func signal(
        sourceID: String,
        payload: HookEventPayload
    ) throws -> HookLifecycleSignal? {
        guard let source = AgentSourceID(rawValue: sourceID) else {
            throw HookEventMappingError.unsupportedSource(sourceID)
        }

        switch source {
        case .claudeCode:
            return try mapSessionHook(
                payload,
                startEvent: "UserPromptSubmit",
                finishEvents: [
                    "Stop": .completed,
                    "StopFailure": .failed,
                ]
            )

        case .geminiCLI:
            return try mapSessionHook(
                payload,
                startEvent: "BeforeAgent",
                finishEvents: ["AfterAgent": .completed]
            )

        case .cursor:
            guard
                payload.hookEventName == "beforeSubmitPrompt"
                    || payload.hookEventName == "stop"
            else {
                return nil
            }
            let threadID = try required(
                payload.conversationID,
                field: "conversation_id"
            )
            let taskID = try required(
                payload.generationID,
                field: "generation_id"
            )
            if payload.hookEventName == "beforeSubmitPrompt" {
                return .started(threadID: threadID, taskID: taskID)
            }
            return .finished(
                threadID: threadID,
                taskID: taskID,
                reason: try cursorCompletionReason(payload.status)
            )

        case .codexDesktop, .openCode, .amp, .trae:
            return nil
        }
    }

    private static func mapSessionHook(
        _ payload: HookEventPayload,
        startEvent: String,
        finishEvents: [String: TaskCompletionReason]
    ) throws -> HookLifecycleSignal? {
        let isStart = payload.hookEventName == startEvent
        let finishReason = finishEvents[payload.hookEventName]
        guard isStart || finishReason != nil else {
            return nil
        }
        let threadID = try required(payload.sessionID, field: "session_id")
        if isStart {
            return .started(threadID: threadID, taskID: nil)
        }
        return .finished(
            threadID: threadID,
            taskID: nil,
            reason: finishReason ?? .completed
        )
    }

    private static func cursorCompletionReason(
        _ status: String?
    ) throws -> TaskCompletionReason {
        let status = try required(status, field: "status")
        switch status {
        case "completed":
            return .completed
        case "aborted":
            return .interrupted
        case "error":
            return .failed
        default:
            throw HookEventMappingError.unsupportedStatus(status)
        }
    }

    private static func required(
        _ value: String?,
        field: String
    ) throws -> String {
        guard let value, !value.isEmpty else {
            throw HookEventMappingError.missingField(field)
        }
        return value
    }
}
