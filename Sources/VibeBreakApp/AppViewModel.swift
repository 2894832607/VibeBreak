import AppKit
import Foundation
import SwiftUI
import VibeBreakCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var applications: [ApplicationChoice] = []
    @Published private(set) var isRefreshingApplications = false
    @Published private(set) var didLoadApplications = false
    @Published private(set) var sourceHealthByID: [String: SourceHealth]
    @Published private(set) var integrationStatusByID: [String: AgentIntegrationStatus]
    @Published private(set) var integrationOperationSourceID: String?
    @Published private(set) var activeTaskCount = 0
    @Published private(set) var lastEventAt: Date?
    @Published private(set) var lastError: String?

    let sourceDescriptors: [AgentSourceDescriptor]
    let sourceDatabaseURL: URL
    let bridgeEventURL: URL
    let diagnosticLogURL: URL

    var onSettingsChange: ((AppSettings) -> Void)?
    var onApplicationsChange: (() -> Void)?
    var onTestStart: (() -> Void)?
    var onTestCompletion: (() -> Void)?

    private let settingsStore: SettingsStore
    private let integrationManager: AgentIntegrationManager
    private var latestSourceError: String?

    init(
        settings: AppSettings,
        settingsStore: SettingsStore,
        integrationManager: AgentIntegrationManager,
        sourceDescriptors: [AgentSourceDescriptor],
        sourceDatabaseURL: URL,
        bridgeEventURL: URL,
        diagnosticLogURL: URL
    ) {
        self.settings = settings
        self.settingsStore = settingsStore
        self.integrationManager = integrationManager
        self.sourceDescriptors = sourceDescriptors
        self.sourceDatabaseURL = sourceDatabaseURL
        self.bridgeEventURL = bridgeEventURL
        self.diagnosticLogURL = diagnosticLogURL
        sourceHealthByID = Dictionary(
            uniqueKeysWithValues: sourceDescriptors.map { ($0.id, .stopped) }
        )
        integrationStatusByID = Dictionary(
            uniqueKeysWithValues: sourceDescriptors.map {
                ($0.id, integrationManager.status(for: $0.id))
            }
        )
        refreshApplications()
    }

    var enabled: Binding<Bool> {
        Binding(
            get: { self.settings.enabled },
            set: { newValue in
                self.updateSettings { $0.enabled = newValue }
            }
        )
    }

    var startApplication: Binding<String> {
        Binding(
            get: { self.settings.startApplicationBundleIdentifier },
            set: { newValue in
                self.updateSettings {
                    $0.startApplicationBundleIdentifier = newValue
                }
            }
        )
    }

    var completionAction: Binding<CompletionAction> {
        Binding(
            get: { self.settings.completionAction },
            set: { newValue in
                self.updateSettings { $0.completionAction = newValue }
            }
        )
    }

    var completionApplication: Binding<String> {
        Binding(
            get: { self.settings.completionApplicationBundleIdentifier },
            set: { newValue in
                self.updateSettings {
                    $0.completionApplicationBundleIdentifier = newValue
                }
            }
        )
    }

    func sourceEnabled(_ sourceID: String) -> Binding<Bool> {
        Binding(
            get: { self.settings.sourceIsEnabled(sourceID) },
            set: { newValue in
                self.updateSettings {
                    $0.setSource(sourceID, enabled: newValue)
                }
            }
        )
    }

    func sourceHealth(for sourceID: String) -> SourceHealth {
        sourceHealthByID[sourceID] ?? .stopped
    }

    func integrationStatus(for sourceID: String) -> AgentIntegrationStatus {
        integrationStatusByID[sourceID] ?? .notInstalled
    }

    func refreshIntegrationStatuses() {
        let refreshed = Dictionary(
            uniqueKeysWithValues: sourceDescriptors.map {
                ($0.id, integrationManager.status(for: $0.id))
            }
        )
        guard refreshed != integrationStatusByID else { return }
        integrationStatusByID = refreshed
        onSettingsChange?(settings)
    }

    func installIntegration(for sourceID: String) {
        guard integrationOperationSourceID == nil else { return }
        integrationOperationSourceID = sourceID
        do {
            try integrationManager.install(sourceID: sourceID)
            integrationStatusByID[sourceID] = integrationManager.status(for: sourceID)
            if !settings.sourceIsEnabled(sourceID) {
                updateSettings { $0.setSource(sourceID, enabled: true) }
            } else {
                onSettingsChange?(settings)
            }
        } catch {
            lastError = "安装接入失败：\(error.localizedDescription)"
        }
        integrationOperationSourceID = nil
    }

    func uninstallIntegration(for sourceID: String) {
        guard integrationOperationSourceID == nil else { return }
        integrationOperationSourceID = sourceID
        do {
            try integrationManager.uninstall(sourceID: sourceID)
            integrationStatusByID[sourceID] = integrationManager.status(for: sourceID)
            if settings.sourceIsEnabled(sourceID) {
                updateSettings { $0.setSource(sourceID, enabled: false) }
            }
        } catch {
            lastError = "移除接入失败：\(error.localizedDescription)"
        }
        integrationOperationSourceID = nil
    }

    func updateSourceHealth(sourceID: String, health: SourceHealth) {
        sourceHealthByID[sourceID] = health
        let name = sourceName(sourceID)
        if case .failed(let message) = health {
            let error = "\(name)：\(message)"
            latestSourceError = error
            lastError = error
        } else if case .incompatible(let message) = health {
            let error = "\(name)：\(message)"
            latestSourceError = error
            lastError = error
        } else if health == .monitoring {
            if lastError == latestSourceError {
                lastError = nil
            }
            latestSourceError = nil
        }
    }

    func record(_ event: LifecycleEvent) {
        lastEventAt = Date()
    }

    func setActiveTaskCount(_ count: Int) {
        activeTaskCount = count
    }

    func reportError(_ message: String) {
        lastError = message
    }

    func clearError() {
        lastError = nil
    }

    func testStartAction() {
        onTestStart?()
    }

    func testCompletionAction() {
        onTestCompletion?()
    }

    func openDiagnosticLog() {
        NSWorkspace.shared.open(diagnosticLogURL)
    }

    func copyDiagnostics() {
        let summary = """
        VibeBreak
        Sources: \(sourceDiagnosticsSummary)
        Active tasks: \(activeTaskCount)
        Last event: \(lastEventDescription)
        Codex database: \(sourceDatabaseURL.path)
        Bridge events: \(bridgeEventURL.path)
        Log: \(diagnosticLogURL.path)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    func refreshApplications() {
        guard !isRefreshingApplications else { return }
        isRefreshingApplications = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let applications = ApplicationCatalog.installedApplications()
            DispatchQueue.main.async {
                guard let self else { return }
                self.applications = applications
                self.didLoadApplications = true
                self.isRefreshingApplications = false
                self.onApplicationsChange?()
            }
        }
    }

    var startApplicationIsAvailable: Bool {
        applicationIsAvailable(settings.startApplicationBundleIdentifier)
    }

    var completionApplicationIsAvailable: Bool {
        settings.completionAction != .openApplication
            || applicationIsAvailable(
                settings.completionApplicationBundleIdentifier
            )
    }

    var hasValidConfiguration: Bool {
        settings.isConfigured
            && hasEnabledKnownSources
            && startApplicationIsAvailable
            && completionApplicationIsAvailable
    }

    var configurationWarning: String? {
        guard didLoadApplications else { return nil }
        if applications.isEmpty {
            return "未发现可用应用，请刷新应用列表"
        }
        if let source = enabledSourceDescriptors.first(where: {
            integrationStatus(for: $0.id) == .notInstalled
        }) {
            return "\(source.name) 尚未安装接入"
        }
        if !hasEnabledKnownSources {
            return "请至少启用一个事件来源"
        }
        if !startApplicationIsAvailable {
            return "任务开始时应用不可用，请重新选择"
        }
        if !completionApplicationIsAvailable {
            return "任务完成后应用不可用，请重新选择"
        }
        return nil
    }

    var sourceHealth: SourceHealth {
        guard !enabledSourceDescriptors.isEmpty else {
            return .stopped
        }
        let values = enabledSourceDescriptors.map { sourceHealth(for: $0.id) }
        if values.contains(where: \.isMonitoring) {
            return .monitoring
        }
        if values.contains(where: { $0 == .connecting }) {
            return .connecting
        }
        if values.contains(where: {
            if case .failed = $0 { return true }
            return false
        }) {
            return .failed("")
        }
        if values.contains(where: {
            if case .incompatible = $0 { return true }
            return false
        }) {
            return .incompatible("")
        }
        return .stopped
    }

    var healthDescription: String {
        guard !enabledSourceDescriptors.isEmpty else {
            return "未选择来源"
        }
        let monitoringCount = enabledSourceDescriptors.filter {
            sourceHealth(for: $0.id).isMonitoring
        }.count
        if monitoringCount == enabledSourceDescriptors.count {
            return "正在监听"
        }
        if monitoringCount > 0 {
            return "部分来源监听中"
        }
        if enabledSourceDescriptors.contains(where: {
            sourceHealth(for: $0.id) == .connecting
        }) {
            return "正在连接"
        }
        if enabledSourceDescriptors.contains(where: {
            if case .failed = sourceHealth(for: $0.id) { return true }
            return false
        }) {
            return "连接失败"
        }
        if enabledSourceDescriptors.contains(where: {
            if case .incompatible = sourceHealth(for: $0.id) { return true }
            return false
        }) {
            return "不兼容"
        }
        return "已停止"
    }

    var lastEventDescription: String {
        guard let lastEventAt else { return "尚无事件" }
        return lastEventAt.formatted(date: .abbreviated, time: .standard)
    }

    var enabledSourceDescriptors: [AgentSourceDescriptor] {
        sourceDescriptors.filter {
            settings.sourceIsEnabled($0.id)
        }
    }

    var enabledOperationalSourceIDs: [String] {
        enabledSourceDescriptors
            .filter { integrationStatus(for: $0.id).isOperational }
            .map(\.id)
    }

    var hasEnabledKnownSources: Bool {
        enabledSourceDescriptors.contains {
            integrationStatus(for: $0.id).isOperational
        }
    }

    var sourceDiagnosticsSummary: String {
        sourceDescriptors.map { descriptor in
            let enabled = settings.sourceIsEnabled(descriptor.id) ? "enabled" : "disabled"
            let integration = integrationLogValue(
                integrationStatus(for: descriptor.id)
            )
            let health = healthLogValue(sourceHealth(for: descriptor.id))
            return "\(descriptor.name)=\(enabled)/\(integration)/\(health)"
        }
        .joined(separator: ", ")
    }

    private func updateSettings(_ mutation: (inout AppSettings) -> Void) {
        var updated = settings
        mutation(&updated)
        do {
            try settingsStore.save(updated)
            settings = updated
            lastError = nil
            onSettingsChange?(updated)
        } catch {
            lastError = "保存设置失败：\(error.localizedDescription)"
        }
    }

    private func applicationIsAvailable(_ bundleIdentifier: String) -> Bool {
        !bundleIdentifier.isEmpty
            && applications.contains {
                $0.bundleIdentifier == bundleIdentifier
            }
    }

    private func sourceName(_ sourceID: String) -> String {
        sourceDescriptors.first { $0.id == sourceID }?.name ?? sourceID
    }

    private func healthLogValue(_ health: SourceHealth) -> String {
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

    private func integrationLogValue(
        _ status: AgentIntegrationStatus
    ) -> String {
        switch status {
        case .builtIn:
            return "built-in"
        case .installed:
            return "installed"
        case .updateAvailable:
            return "update-available"
        case .notInstalled:
            return "not-installed"
        case .manual:
            return "manual"
        }
    }
}
