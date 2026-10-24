import Foundation
import Testing
@testable import VibeBreakCore

struct HookEventMapperTests {
    @Test(arguments: ["turn-a", "turn-b"])
    func mapsCodexTurnBySessionAndTurnID(turnID: String) throws {
        for (event, expected) in [
            ("UserPromptSubmit", HookLifecycleSignal.started(
                threadID: "codex-session", taskID: turnID
            )),
            ("Stop", .finished(
                threadID: "codex-session", taskID: turnID, reason: .completed
            )),
            ("Interrupt", .finished(
                threadID: "codex-session", taskID: turnID, reason: .interrupted
            )),
        ] {
            let input = try payload(
                """
                {"hook_event_name":"\(event)","session_id":"codex-session","turn_id":"\(turnID)"}
                """
            )
            #expect(
                try HookEventMapper.signal(sourceID: "codex-hooks", payload: input)
                    == expected
            )
        }
    }

    @Test(arguments: ["UserPromptSubmit", "Stop", "Interrupt"])
    func rejectsCodexEventsWithoutPairingIDs(event: String) throws {
        for (fields, missing) in [
            (#""session_id":"session""#, "turn_id"),
            (#""turn_id":"turn""#, "session_id"),
            (#""session_id":"session","turn_id":"""#, "turn_id"),
        ] {
            let input = try payload(
                "{\"hook_event_name\":\"\(event)\",\(fields)}"
            )
            #expect(throws: HookEventMappingError.missingField(missing)) {
                try HookEventMapper.signal(sourceID: "codex-hooks", payload: input)
            }
        }
    }

    @Test func ignoresNonMainTurnCodexEvents() throws {
        for event in ["SessionStart", "SessionEnd", "SubagentStop", "PreToolUse"] {
            let input = try payload("{\"hook_event_name\":\"\(event)\"}")
            #expect(
                try HookEventMapper.signal(sourceID: "codex-hooks", payload: input)
                    == nil
            )
        }
    }

    @Test func mapsClaudeTurn() throws {
        let start = try payload(
            """
            {"hook_event_name":"UserPromptSubmit","session_id":"claude-session"}
            """
        )
        let finish = try payload(
            """
            {"hook_event_name":"StopFailure","session_id":"claude-session"}
            """
        )

        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.claudeCode.rawValue,
                payload: start
            ) == .started(threadID: "claude-session", taskID: nil)
        )
        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.claudeCode.rawValue,
                payload: finish
            ) == .finished(
                threadID: "claude-session",
                taskID: nil,
                reason: .failed
            )
        )
    }

    @Test func mapsGeminiTurn() throws {
        let start = try payload(
            """
            {"hook_event_name":"BeforeAgent","session_id":"gemini-session"}
            """
        )
        let finish = try payload(
            """
            {"hook_event_name":"AfterAgent","session_id":"gemini-session"}
            """
        )

        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.geminiCLI.rawValue,
                payload: start
            ) == .started(threadID: "gemini-session", taskID: nil)
        )
        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.geminiCLI.rawValue,
                payload: finish
            ) == .finished(
                threadID: "gemini-session",
                taskID: nil,
                reason: .completed
            )
        )
    }

    @Test func mapsCursorGenerationAndStatus() throws {
        let start = try payload(
            """
            {
              "hook_event_name":"beforeSubmitPrompt",
              "conversation_id":"cursor-conversation",
              "generation_id":"cursor-generation"
            }
            """
        )
        let finish = try payload(
            """
            {
              "hook_event_name":"stop",
              "conversation_id":"cursor-conversation",
              "generation_id":"cursor-generation",
              "status":"aborted"
            }
            """
        )

        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.cursor.rawValue,
                payload: start
            ) == .started(
                threadID: "cursor-conversation",
                taskID: "cursor-generation"
            )
        )
        #expect(
            try HookEventMapper.signal(
                sourceID: AgentSourceID.cursor.rawValue,
                payload: finish
            ) == .finished(
                threadID: "cursor-conversation",
                taskID: "cursor-generation",
                reason: .interrupted
            )
        )
    }

    @Test func rejectsKnownEventWithoutStableThreadID() throws {
        let input = try payload(
            """
            {"hook_event_name":"BeforeAgent"}
            """
        )

        let error = #expect(throws: (any Error).self) {
            try HookEventMapper.signal(
                sourceID: AgentSourceID.geminiCLI.rawValue,
                payload: input
            )
        }
        #expect(
            error as? HookEventMappingError
                == .missingField("session_id")
        )
    }

    @Test func rejectsUnknownCursorCompletionStatus() throws {
        let input = try payload(
            """
            {
              "hook_event_name":"stop",
              "conversation_id":"cursor-conversation",
              "generation_id":"cursor-generation",
              "status":"waiting"
            }
            """
        )

        let error = #expect(throws: (any Error).self) {
            try HookEventMapper.signal(
                sourceID: AgentSourceID.cursor.rawValue,
                payload: input
            )
        }
        #expect(
            error as? HookEventMappingError
                == .unsupportedStatus("waiting")
        )
    }

    private func payload(_ json: String) throws -> HookEventPayload {
        try HookEventMapper.decode(data: Data(json.utf8))
    }
}
