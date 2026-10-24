import Foundation

public protocol ApplicationOpening {
    var frontmostApplicationBundleIdentifier: String? { get }

    func openApplication(bundleIdentifier: String) throws
}

public extension ApplicationOpening {
    var frontmostApplicationBundleIdentifier: String? {
        nil
    }
}

public final class FocusAutomation {
    public var onActiveCountChange: ((Int) -> Void)?
    public var onActionError: ((String) -> Void)?

    private let applicationOpener: ApplicationOpening
    private var settings: AppSettings
    private var stateMachine = TaskStateMachine()
    private var ownsFocus = false
    private var previousApplicationBundleIdentifier: String?

    public init(
        settings: AppSettings,
        applicationOpener: ApplicationOpening
    ) {
        self.settings = settings
        self.applicationOpener = applicationOpener
    }

    public func updateSettings(_ settings: AppSettings) {
        let removedSources = Set(self.settings.enabledSourceIdentifiers)
            .subtracting(settings.enabledSourceIdentifiers)
        self.settings = settings
        if !settings.enabled {
            reset()
        } else {
            for sourceID in removedSources {
                invalidateSource(sourceID)
            }
        }
    }

    public func handle(_ event: LifecycleEvent) {
        let transition = stateMachine.apply(event)
        guard transition != .ignored else { return }
        onActiveCountChange?(stateMachine.activeCount)

        switch transition {
        case .becameActive:
            openStartApplicationIfConfigured()

        case .becameIdle:
            runCompletionActionIfNeeded()

        case .activeCountChanged, .ignored:
            break
        }
    }

    public func testStartAction() {
        open(
            bundleIdentifier: settings.startApplicationBundleIdentifier,
            context: "无法打开任务运行时应用"
        )
    }

    public func testCompletionAction() {
        guard settings.completionAction == .openApplication else { return }
        open(
            bundleIdentifier: settings.completionApplicationBundleIdentifier,
            context: "无法打开任务完成后应用"
        )
    }

    public func reset() {
        stateMachine.reset()
        ownsFocus = false
        previousApplicationBundleIdentifier = nil
        onActiveCountChange?(0)
    }

    public func invalidateSource(_ sourceID: String) {
        let previousCount = stateMachine.activeCount
        stateMachine.invalidateSource(sourceID)
        guard previousCount != stateMachine.activeCount else { return }
        if stateMachine.activeCount == 0 {
            ownsFocus = false
            previousApplicationBundleIdentifier = nil
        }
        onActiveCountChange?(stateMachine.activeCount)
    }

    private func openStartApplicationIfConfigured() {
        guard settings.enabled, settings.isConfigured else { return }
        previousApplicationBundleIdentifier =
            applicationOpener.frontmostApplicationBundleIdentifier
        ownsFocus = open(
            bundleIdentifier: settings.startApplicationBundleIdentifier,
            context: "无法打开任务运行时应用"
        )
        if !ownsFocus {
            previousApplicationBundleIdentifier = nil
        }
    }

    private func runCompletionActionIfNeeded() {
        defer {
            ownsFocus = false
            previousApplicationBundleIdentifier = nil
        }
        guard ownsFocus, settings.enabled else { return }
        switch settings.completionAction {
        case .openApplication:
            open(
                bundleIdentifier: settings.completionApplicationBundleIdentifier,
                context: "无法打开任务完成后应用"
            )
        case .restorePreviousApplication:
            guard
                let previousApplicationBundleIdentifier,
                !previousApplicationBundleIdentifier.isEmpty
            else {
                onActionError?("无法恢复任务开始前应用：未检测到前台应用")
                return
            }
            open(
                bundleIdentifier: previousApplicationBundleIdentifier,
                context: "无法恢复任务开始前应用"
            )
        case .stay:
            break
        }
    }

    @discardableResult
    private func open(bundleIdentifier: String, context: String) -> Bool {
        guard !bundleIdentifier.isEmpty else {
            onActionError?("\(context)：尚未选择应用")
            return false
        }
        do {
            try applicationOpener.openApplication(bundleIdentifier: bundleIdentifier)
            return true
        } catch {
            onActionError?("\(context)：\(error.localizedDescription)")
            return false
        }
    }
}
