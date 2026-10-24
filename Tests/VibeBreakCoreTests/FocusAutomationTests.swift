import Testing
@testable import VibeBreakCore

struct FocusAutomationTests {
    @Test func opensStartAndCompletionApplicationsOnce() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.codex"
            ),
            applicationOpener: opener
        )
        let first = task(id: "1")
        let second = task(id: "2")

        automation.handle(.started(first))
        automation.handle(.started(second))
        automation.handle(.finished(first, reason: .completed))
        automation.handle(.finished(second, reason: .completed))

        #expect(opener.openedBundleIdentifiers == ["app.break", "app.codex"])
    }

    @Test func stayCompletionDoesNotOpenAnotherApplication() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .stay,
                completionApplicationBundleIdentifier: ""
            ),
            applicationOpener: opener
        )
        let task = task(id: "1")

        automation.handle(.started(task))
        automation.handle(.finished(task, reason: .completed))

        #expect(opener.openedBundleIdentifiers == ["app.break"])
    }

    @Test func disabledAutomationDoesNotRunActions() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: false,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.codex"
            ),
            applicationOpener: opener
        )
        let task = task(id: "1")

        automation.handle(.started(task))
        automation.handle(.finished(task, reason: .completed))

        #expect(opener.openedBundleIdentifiers.isEmpty)
    }

    @Test func addingEnabledSourcePreservesActiveTasks() {
        let opener = RecordingApplicationOpener()
        var settings = AppSettings(
            enabled: true,
            startApplicationBundleIdentifier: "app.break",
            completionAction: .openApplication,
            completionApplicationBundleIdentifier: "app.codex"
        )
        let automation = FocusAutomation(
            settings: settings,
            applicationOpener: opener
        )
        var activeCounts: [Int] = []
        automation.onActiveCountChange = { activeCounts.append($0) }

        automation.handle(.started(task(id: "1")))
        settings.setSource(AgentSourceID.cursor.rawValue, enabled: true)
        automation.updateSettings(settings)

        automation.handle(.finished(task(id: "1"), reason: .completed))
        #expect(activeCounts == [1, 0])
        #expect(opener.openedBundleIdentifiers == ["app.break", "app.codex"])
    }

    @Test func restoresApplicationThatWasFrontmostBeforeFirstTask() {
        let opener = RecordingApplicationOpener()
        opener.frontmostApplicationBundleIdentifier = "app.agent"
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .restorePreviousApplication,
                completionApplicationBundleIdentifier: ""
            ),
            applicationOpener: opener
        )
        let first = task(id: "1")
        let second = task(id: "2")

        automation.handle(.started(first))
        opener.frontmostApplicationBundleIdentifier = "app.other"
        automation.handle(.started(second))
        automation.handle(.finished(first, reason: .completed))
        automation.handle(.finished(second, reason: .completed))

        #expect(opener.openedBundleIdentifiers == ["app.break", "app.agent"])
    }

    @Test func reportsMissingFrontmostApplicationForRestore() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .restorePreviousApplication,
                completionApplicationBundleIdentifier: ""
            ),
            applicationOpener: opener
        )
        var errorMessage: String?
        automation.onActionError = { errorMessage = $0 }
        let task = task(id: "1")

        automation.handle(.started(task))
        automation.handle(.finished(task, reason: .completed))

        #expect(errorMessage == "无法恢复任务开始前应用：未检测到前台应用")
        #expect(opener.openedBundleIdentifiers == ["app.break"])
    }

    @Test func invalidationPreservesOtherSourcesAndTheirCompletionAction() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                enabledSourceIdentifiers: ["codex", "cursor"],
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.codex"
            ),
            applicationOpener: opener
        )
        let bridge = AgentTask(sourceID: "cursor", threadID: "thread", taskID: "bridge")
        var counts: [Int] = []
        automation.onActiveCountChange = { counts.append($0) }
        automation.handle(.started(task(id: "1")))
        automation.handle(.started(bridge))
        automation.invalidateSource("codex")
        #expect(counts == [1, 2, 1])
        #expect(opener.openedBundleIdentifiers == ["app.break"])
        automation.handle(.finished(bridge, reason: .completed))
        #expect(opener.openedBundleIdentifiers == ["app.break", "app.codex"])
    }

    @Test func invalidatingLastSourceDoesNotRunCompletionOrRetainFocusOwnership() {
        let opener = RecordingApplicationOpener()
        let automation = FocusAutomation(
            settings: AppSettings(
                enabled: true,
                startApplicationBundleIdentifier: "app.break",
                completionAction: .openApplication,
                completionApplicationBundleIdentifier: "app.codex"
            ),
            applicationOpener: opener
        )
        automation.handle(.started(task(id: "1")))
        automation.invalidateSource("codex")
        automation.handle(.finished(task(id: "1"), reason: .completed))
        #expect(opener.openedBundleIdentifiers == ["app.break"])
        automation.handle(.started(task(id: "2")))
        automation.handle(.finished(task(id: "2"), reason: .completed))
        #expect(opener.openedBundleIdentifiers == ["app.break", "app.break", "app.codex"])
    }

    @Test func removingSourceKeepsOtherSourceTasks() {
        let opener = RecordingApplicationOpener()
        var settings = AppSettings(
            enabled: true,
            enabledSourceIdentifiers: ["codex", "cursor"],
            startApplicationBundleIdentifier: "app.break",
            completionAction: .openApplication,
            completionApplicationBundleIdentifier: "app.codex"
        )
        let automation = FocusAutomation(settings: settings, applicationOpener: opener)
        let bridge = AgentTask(sourceID: "cursor", threadID: "thread", taskID: "bridge")
        var counts: [Int] = []
        automation.onActiveCountChange = { counts.append($0) }
        automation.handle(.started(task(id: "1")))
        automation.handle(.started(bridge))
        settings.setSource("codex", enabled: false)
        automation.updateSettings(settings)
        #expect(counts == [1, 2, 1])
        automation.handle(.finished(bridge, reason: .completed))
        #expect(opener.openedBundleIdentifiers == ["app.break", "app.codex"])
    }

    private func task(id: String) -> AgentTask {
        AgentTask(sourceID: "codex", threadID: "thread-\(id)", taskID: id)
    }
}

private final class RecordingApplicationOpener: ApplicationOpening {
    private(set) var openedBundleIdentifiers: [String] = []
    var frontmostApplicationBundleIdentifier: String?

    func openApplication(bundleIdentifier: String) throws {
        openedBundleIdentifiers.append(bundleIdentifier)
    }
}
