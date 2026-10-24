import Testing
@testable import VibeBreakCore

struct TaskStateMachineTests {
    private let first = AgentTask(
        sourceID: "codex",
        threadID: "thread-1",
        taskID: "task-1"
    )
    private let second = AgentTask(
        sourceID: "codex",
        threadID: "thread-2",
        taskID: "task-2"
    )

    @Test func transitionsAcrossConcurrentTasks() {
        var state = TaskStateMachine()

        #expect(state.apply(.started(first)) == .becameActive)
        #expect(state.apply(.started(second)) == .activeCountChanged)
        #expect(state.activeCount == 2)

        #expect(
            state.apply(.finished(first, reason: .completed))
                == .activeCountChanged
        )
        #expect(state.activeCount == 1)

        #expect(
            state.apply(.finished(second, reason: .interrupted))
                == .becameIdle
        )
        #expect(state.activeCount == 0)
    }

    @Test func duplicateAndUnknownEventsAreIgnored() {
        var state = TaskStateMachine()

        #expect(state.apply(.started(first)) == .becameActive)
        #expect(state.apply(.started(first)) == .ignored)
        #expect(
            state.apply(.finished(second, reason: .completed))
                == .ignored
        )
        #expect(state.activeCount == 1)
    }
}
