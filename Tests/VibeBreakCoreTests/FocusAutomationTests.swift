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

    @Test func changingEnabledSourcesClearsActiveTasks() {
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

        #expect(activeCounts == [1, 0])
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
