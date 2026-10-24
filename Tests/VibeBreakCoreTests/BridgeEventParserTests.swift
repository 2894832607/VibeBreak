import Testing
@testable import VibeBreakCore

struct BridgeEventParserTests {
    @Test func parsesStartedBridgeEvent() throws {
        let line = """
        {"event":"started","source":"trae","task_id":"task-1","thread_id":"thread-1","version":1}
        """

        let record = try BridgeEventParser.decode(line: line)
        let event = BridgeEventParser.lifecycleEvent(
            from: record,
            acceptedSourceID: AgentSourceID.trae.rawValue
        )

        #expect(
            event == .started(
                AgentTask(
                    sourceID: AgentSourceID.trae.rawValue,
                    threadID: "thread-1",
                    taskID: "task-1"
                )
            )
        )
    }

    @Test func mapsInterruptedBridgeEventToFinishedEvent() throws {
        let line = """
        {"event":"interrupted","source":"claude-code","task_id":"task-2","thread_id":"thread-2","version":1}
        """

        let record = try BridgeEventParser.decode(line: line)
        let event = BridgeEventParser.lifecycleEvent(
            from: record,
            acceptedSourceID: AgentSourceID.claudeCode.rawValue
        )

        #expect(
            event == .finished(
                AgentTask(
                    sourceID: AgentSourceID.claudeCode.rawValue,
                    threadID: "thread-2",
                    taskID: "task-2"
                ),
                reason: .interrupted
            )
        )
    }

    @Test func ignoresOtherBridgeSources() throws {
        let line = """
        {"event":"started","source":"trae","task_id":"task-1","thread_id":"thread-1","version":1}
        """

        let record = try BridgeEventParser.decode(line: line)

        #expect(
            BridgeEventParser.lifecycleEvent(
                from: record,
                acceptedSourceID: AgentSourceID.claudeCode.rawValue
            ) == nil
        )
    }

    @Test func rejectsMissingTaskID() {
        let line = """
        {"event":"started","source":"trae","task_id":"","thread_id":"thread-1","version":1}
        """

        let error = #expect(throws: (any Error).self) {
            try BridgeEventParser.decode(line: line)
        }
        #expect(error as? BridgeEventError == .emptyTaskID)
    }
}
