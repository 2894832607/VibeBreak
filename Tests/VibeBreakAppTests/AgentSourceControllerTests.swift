import Foundation
import Testing
@testable import VibeBreakApp
import VibeBreakCore

@MainActor
struct AgentSourceControllerTests {
    @Test func disabledSourceDropsQueuedCallbacksEvenAfterReenable() async {
        let source = ControllableEventSource()
        let controller = AgentSourceController(sources: [source])
        var events: [LifecycleEvent] = []
        var healthValues: [SourceHealth] = []
        var invalidatedIDs: [String] = []
        controller.onEvent = { events.append($0) }
        controller.onHealthChange = { _, health in healthValues.append(health) }
        controller.onStateInvalidated = { invalidatedIDs.append($0) }

        controller.applyEnabledSourceIDs([source.id])
        let oldEventCallback = source.onEvent
        let oldHealthCallback = source.onHealthChange
        let oldInvalidationCallback = source.onStateInvalidated
        oldEventCallback?(.started(source.task))
        oldHealthCallback?(.failed("temporary"))
        oldInvalidationCallback?()
        controller.applyEnabledSourceIDs([])
        controller.applyEnabledSourceIDs([source.id])
        // Also simulate a callback already captured by the old source worker.
        oldEventCallback?(.started(source.task))
        await drainMainQueue()
        #expect(events.isEmpty)
        #expect(healthValues.isEmpty)
        #expect(invalidatedIDs == [source.id])

        source.onEvent?(.started(source.task))
        await drainMainQueue()
        #expect(events == [.started(source.task)])
    }

    @Test func failureDoesNotInvalidateEitherSource() async {
        let codex = ControllableEventSource()
        let bridge = ControllableEventSource(id: "cursor")
        let controller = AgentSourceController(sources: [codex, bridge])
        let opener = SourceTestOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                enabledSourceIdentifiers: [codex.id, bridge.id],
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.work"
            ),
            applicationOpener: opener
        )
        var counts: [Int] = []
        var healthValues: [SourceHealth] = []
        automation.onActiveCountChange = { counts.append($0) }
        controller.onEvent = { automation.handle($0) }
        controller.onStateInvalidated = { automation.invalidateSource($0) }
        controller.onHealthChange = { _, health in healthValues.append(health) }
        controller.applyEnabledSourceIDs([codex.id, bridge.id])
        codex.onEvent?(.started(codex.task))
        bridge.onEvent?(.started(bridge.task))
        codex.onHealthChange?(.failed("temporary disconnect"))
        bridge.onHealthChange?(.failed("malformed line"))
        await drainMainQueue()
        #expect(counts == [1, 2])
        #expect(healthValues.count == 2)
        bridge.onEvent?(.finished(bridge.task, reason: .completed))
        codex.onEvent?(.finished(codex.task, reason: .interrupted))
        await drainMainQueue()
        #expect(counts == [1, 2, 1, 0])
        #expect(opener.opened == ["app.break", "app.work"])
    }

    @Test func stopAllDropsQueuedCallbacks() async {
        let source = ControllableEventSource()
        let controller = AgentSourceController(sources: [source])
        var events: [LifecycleEvent] = []
        controller.onEvent = { events.append($0) }
        controller.applyEnabledSourceIDs([source.id])
        source.onEvent?(.started(source.task))
        controller.stopAll()
        await drainMainQueue()
        #expect(events.isEmpty)
    }

    @Test func sourceInvalidationOnlyClearsThatSourceWithoutCompletion() async {
        let codex = ControllableEventSource()
        let bridge = ControllableEventSource(id: "cursor")
        let controller = AgentSourceController(sources: [codex, bridge])
        let opener = SourceTestOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                enabledSourceIdentifiers: [codex.id, bridge.id],
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.work"
            ),
            applicationOpener: opener
        )
        var counts: [Int] = []
        automation.onActiveCountChange = { counts.append($0) }
        controller.onEvent = { automation.handle($0) }
        controller.onStateInvalidated = { automation.invalidateSource($0) }
        controller.applyEnabledSourceIDs([codex.id, bridge.id])
        codex.onEvent?(.started(codex.task))
        bridge.onEvent?(.started(bridge.task))
        codex.onStateInvalidated?()
        await drainMainQueue()
        #expect(counts == [1, 2, 1])
        #expect(opener.opened == ["app.break"])
        bridge.onEvent?(.finished(bridge.task, reason: .completed))
        await drainMainQueue()
        #expect(counts == [1, 2, 1, 0])
        #expect(opener.opened == ["app.break", "app.work"])
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

private final class ControllableEventSource: AgentEventSource {
    let id: String
    var onEvent: ((LifecycleEvent) -> Void)?
    var onHealthChange: ((SourceHealth) -> Void)?
    var onStateInvalidated: (() -> Void)?
    var task: AgentTask {
        AgentTask(sourceID: id, threadID: "thread", taskID: "task")
    }

    init(id: String = "codex-desktop") { self.id = id }
    func start() {}
    func stop() {}
}

private final class SourceTestOpener: ApplicationOpening {
    var opened: [String] = []
    func openApplication(bundleIdentifier: String) throws {
        opened.append(bundleIdentifier)
    }
}
