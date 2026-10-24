import AppKit
import Foundation
import VibeBreakCore

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.squareLength
    )
    private let settingsStore = SettingsStore()
    private let logger = DiagnosticLogger()
    private let applicationOpener = MacApplicationOpener()
    private let instanceGuard = AppInstanceGuard()

    private var sourceController: AgentSourceController?
    private var automation: FocusAutomation?
    private var model: AppViewModel?
    private var settingsWindow: SettingsWindowController?
    private var settingsRequestObserver: NSObjectProtocol?

    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var testMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch instanceGuard.acquire() {
        case .acquired:
            observeSettingsRequests()
        case .alreadyRunning:
            AppInstanceGuard.requestSettingsFromRunningInstance()
            NSApp.terminate(nil)
            return
        case .failed:
            logger.write("instance.error reason=lock-unavailable")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        configureMenu()

        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite")
        let bridgeEventURL = settingsStore.currentURL
            .deletingLastPathComponent()
            .appendingPathComponent("bridge", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        let sourceDescriptors = AgentSourceDescriptor.builtIn(
            codexDatabaseURL: databaseURL,
            bridgeEventURL: bridgeEventURL
        )

        let initialSettings: AppSettings
        let settingsError: String?
        do {
            initialSettings = try settingsStore.load()
            settingsError = nil
        } catch {
            initialSettings = .initial
            settingsError = "读取设置失败：\(error.localizedDescription)"
        }

        let model = AppViewModel(
            settings: initialSettings,
            settingsStore: settingsStore,
            integrationManager: AgentIntegrationManager(),
            sourceDescriptors: sourceDescriptors,
            sourceDatabaseURL: databaseURL,
            bridgeEventURL: bridgeEventURL,
            diagnosticLogURL: logger.fileURL
        )
        var safeInitialSettings = initialSettings
        safeInitialSettings.enabled = false
        let automation = FocusAutomation(
            settings: safeInitialSettings,
            applicationOpener: applicationOpener
        )
        let bridgeSources: [AgentEventSource] = AgentSourceID.allCases
            .filter(\.usesBridge)
            .map {
                JSONLBridgeEventSource(
                    id: $0.rawValue,
                    fileURL: bridgeEventURL
                )
            }
        let sourceController = AgentSourceController(
            sources: [
                CodexSQLiteEventSource(databaseURL: databaseURL),
            ] + bridgeSources
        )

        self.model = model
        self.automation = automation
        self.sourceController = sourceController
        settingsWindow = SettingsWindowController(model: model)

        bind(
            model: model,
            automation: automation,
            sourceController: sourceController
        )

        if let settingsError {
            model.reportError(settingsError)
            logger.write("settings.error message=\(settingsError)")
        }

        sourceController.applyEnabledSourceIDs(model.enabledOperationalSourceIDs)
        refreshMenu()

        if !CommandLine.arguments.contains("--background") {
            settingsWindow?.present()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let settingsRequestObserver {
            DistributedNotificationCenter.default().removeObserver(
                settingsRequestObserver
            )
        }
        sourceController?.stopAll()
        automation?.reset()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        model?.refreshIntegrationStatuses()
        settingsWindow?.present()
        return true
    }

    private func bind(
        model: AppViewModel,
        automation: FocusAutomation,
        sourceController: AgentSourceController
    ) {
        model.onSettingsChange = { [weak self, weak model, weak automation] settings in
            if let model, let automation {
                self?.applyRuntimeSettings(model: model, automation: automation)
                self?.sourceController?.applyEnabledSourceIDs(
                    model.enabledOperationalSourceIDs
                )
            }
            self?.logger.write(
                "settings.saved enabled=\(settings.enabled) configured=\(settings.isConfigured) sources=\(settings.enabledSourceIdentifiers.joined(separator: ","))"
            )
            self?.refreshMenu()
        }
        model.onApplicationsChange = { [weak self, weak model, weak automation] in
            if let model, let automation {
                self?.applyRuntimeSettings(model: model, automation: automation)
            }
            self?.refreshMenu()
        }
        model.onTestStart = { [weak self, weak model, weak automation] in
            guard model?.startApplicationIsAvailable == true else { return }
            self?.logger.write("action.test.start")
            automation?.testStartAction()
        }
        model.onTestCompletion = { [weak self, weak model, weak automation] in
            guard model?.completionApplicationIsAvailable == true else { return }
            self?.logger.write("action.test.completion")
            automation?.testCompletionAction()
        }

        automation.onActiveCountChange = { [weak self, weak model] count in
            model?.setActiveTaskCount(count)
            self?.refreshMenu()
        }
        automation.onActionError = { [weak self, weak model] message in
            model?.reportError(message)
            self?.logger.write("action.error message=\(message)")
            self?.refreshMenu()
        }

        sourceController.onHealthChange = { [weak self, weak model, weak automation] sourceID, health in
            model?.updateSourceHealth(sourceID: sourceID, health: health)
            if case .failed = health {
                automation?.reset()
            } else if case .incompatible = health {
                automation?.reset()
            }
            self?.logger.write(
                "source.health source=\(sourceID) value=\(Self.healthLogValue(health))"
            )
            self?.refreshMenu()
        }
        sourceController.onEvent = { [weak self, weak model, weak automation] event in
            model?.record(event)
            automation?.handle(event)
            self?.logger.write(Self.eventLogValue(event))
            self?.refreshMenu()
        }
    }

    private func applyRuntimeSettings(
        model: AppViewModel,
        automation: FocusAutomation
    ) {
        var runtimeSettings = model.settings
        runtimeSettings.enabled =
            runtimeSettings.enabled && model.hasValidConfiguration
        automation.updateSettings(runtimeSettings)
    }

    private func observeSettingsRequests() {
        settingsRequestObserver = DistributedNotificationCenter.default().addObserver(
            forName: AppInstanceGuard.showSettingsNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.model?.refreshIntegrationStatuses()
                self?.settingsWindow?.present()
            }
        }
    }

    private func configureMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "正在启动", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "打开设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        toggleMenuItem = NSMenuItem(
            title: "启用自动切换",
            action: #selector(toggleAutomation),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        testMenuItem = NSMenuItem(
            title: "测试开始动作",
            action: #selector(testStartAction),
            keyEquivalent: ""
        )
        testMenuItem.target = self
        menu.addItem(testMenuItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 VibeBreak",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshMenu() {
        guard let model else { return }

        toggleMenuItem.state = model.settings.enabled ? .on : .off
        testMenuItem.isEnabled = model.startApplicationIsAvailable

        let iconName: String
        if !model.hasValidConfiguration {
            statusMenuItem.title = "需要完成设置"
            iconName = "exclamationmark.triangle.fill"
        } else if !model.sourceHealth.isMonitoring {
            statusMenuItem.title = model.healthDescription
            iconName = "bolt.slash.fill"
        } else if model.activeTaskCount > 0 {
            statusMenuItem.title = "运行中（\(model.activeTaskCount)）"
            iconName = "bolt.horizontal.fill"
        } else if model.settings.enabled {
            statusMenuItem.title = "已开启，正在监听"
            iconName = "bolt.fill"
        } else {
            statusMenuItem.title = "已关闭"
            iconName = "bolt.slash.fill"
        }

        statusItem.button?.image = symbol(named: iconName)
        statusItem.button?.toolTip = "VibeBreak：\(statusMenuItem.title)"
    }

    private func symbol(named name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    @objc private func openSettings() {
        model?.refreshIntegrationStatuses()
        settingsWindow?.present()
    }

    @objc private func toggleAutomation() {
        guard let model else { return }
        model.enabled.wrappedValue.toggle()
    }

    @objc private func testStartAction() {
        model?.testStartAction()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static func healthLogValue(_ health: SourceHealth) -> String {
        switch health {
        case .stopped:
            return "stopped"
        case .connecting:
            return "connecting"
        case .monitoring:
            return "monitoring"
        case .incompatible:
            return "incompatible"
        case .failed:
            return "failed"
        }
    }

    private static func eventLogValue(_ event: LifecycleEvent) -> String {
        let task = event.task
        switch event {
        case .started:
            return "event.started source=\(task.sourceID) task=\(short(task.taskID))"
        case .finished(_, let reason):
            return "event.finished source=\(task.sourceID) task=\(short(task.taskID)) reason=\(reason.rawValue)"
        }
    }

    private static func short(_ value: String) -> String {
        String(value.prefix(13))
    }
}

@main
private enum VibeBreakMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
