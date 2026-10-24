import Testing
@testable import VibeBreakCore

struct CodexLogParserTests {
    @Test func parsesUserInputAsStart() {
        let taskID = "019fff02-cded-7d10-a9cb-63fd97d5b080"
        let record = CodexLogRecord(
            rowID: 1,
            target: CodexLogParser.handlersTarget,
            threadID: "thread-1",
            body: """
            session_loop{thread_id=thread-1}: Submission sub=Submission { id: "\(taskID)", op: UserInput { items: [] } }
            """
        )

        #expect(
            CodexLogParser.parse(record)
                == .started(threadID: "thread-1", taskID: taskID)
        )
    }

    @Test func ignoresNonUserSubmission() {
        let record = CodexLogRecord(
            rowID: 1,
            target: CodexLogParser.handlersTarget,
            threadID: "thread-1",
            body: """
            session_loop{thread_id=thread-1}: Submission sub=Submission { id: "interrupt-1", op: Interrupt }
            """
        )

        #expect(CodexLogParser.parse(record) == nil)
    }

    @Test func ignoresIntermediateFollowUp() {
        let record = CodexLogRecord(
            rowID: 2,
            target: CodexLogParser.turnTarget,
            threadID: "thread-1",
            body: """
            run_turn: turn_id=task-1 model_needs_follow_up=false needs_follow_up=true
            """
        )

        #expect(CodexLogParser.parse(record) == nil)
    }

    @Test func parsesSettledTurnAsCompletion() {
        let record = CodexLogRecord(
            rowID: 3,
            target: CodexLogParser.turnTarget,
            threadID: "thread-1",
            body: "run_turn: post sampling token usage turn_id=task-1 needs_follow_up=false "
        )

        #expect(
            CodexLogParser.parse(record)
                == .completed(threadID: "thread-1", taskID: "task-1")
        )
    }

    @Test func parsesExplicitInterrupt() {
        let record = CodexLogRecord(
            rowID: 4,
            target: CodexLogParser.sessionTarget,
            threadID: "thread-1",
            body: "interrupt received: abort current task, if any"
        )

        #expect(
            CodexLogParser.parse(record)
                == .interrupted(threadID: "thread-1")
        )
    }
}
