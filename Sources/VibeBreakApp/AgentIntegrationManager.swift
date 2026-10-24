import Foundation
import VibeBreakCore

enum AgentIntegrationStatus: Equatable {
    case builtIn
    case installed
    case updateAvailable
    case notInstalled
    case manual

    var isOperational: Bool {
        switch self {
        case .builtIn, .installed, .updateAvailable, .manual:
            return true
        case .notInstalled:
            return false
        }
    }
}

enum AgentIntegrationError: LocalizedError {
    case unsupportedSource(String)
    case invalidConfiguration(String)
    case missingBundledIntegration(String)
    case modifiedManagedPlugin(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource(let sourceID):
            return "来源 \(sourceID) 不支持自动安装"
        case .invalidConfiguration(let path):
            return "无法安全修改配置：\(path)"
        case .missingBundledIntegration(let name):
            return "应用缺少接入资源：\(name)"
        case .modifiedManagedPlugin(let path):
            return "接入文件已被修改，未覆盖：\(path)"
        }
    }
}

final class AgentIntegrationManager {
    private static let managedPluginMarker = "// VibeBreak managed integration v1"

    private struct HookSpec {
        let source: AgentSourceID
        let url: URL
        let events: [String]
        let layout: JSONHookLayout
    }

    private let fileManager: FileManager
    private let jsonHooks: JSONHookConfiguration
    private let homeURL: URL
    private let resourceURL: URL?

    init(
        fileManager: FileManager = .default,
        homeURL: URL? = nil,
        resourceURL: URL? = Bundle.main.resourceURL
    ) {
        self.fileManager = fileManager
        jsonHooks = JSONHookConfiguration(fileManager: fileManager)
        self.homeURL = homeURL ?? fileManager.homeDirectoryForCurrentUser
        self.resourceURL = resourceURL
    }

    func status(for sourceID: String) -> AgentIntegrationStatus {
        guard let source = AgentSourceID(rawValue: sourceID) else {
            return .notInstalled
        }
        switch source {
        case .codexDesktop:
            return .builtIn
        case .trae:
            return .manual
        case .claudeCode, .cursor, .geminiCLI:
            guard let spec = hookSpec(for: source) else { return .notInstalled }
            return jsonHooks.containsCommand(
                at: spec.url,
                events: spec.events,
                command: hookCommand(for: spec.source)
            ) ? .installed : .notInstalled
        case .openCode, .amp:
            return managedPluginStatus(for: source)
        }
    }

    func install(sourceID: String) throws {
        guard let source = AgentSourceID(rawValue: sourceID) else {
            throw AgentIntegrationError.unsupportedSource(sourceID)
        }
        if let spec = hookSpec(for: source) {
            try jsonHooks.install(
                at: spec.url,
                events: spec.events,
                command: hookCommand(for: source),
                layout: spec.layout
            )
            return
        }
        if source == .openCode || source == .amp {
            try installPlugin(for: source)
            return
        }
        throw AgentIntegrationError.unsupportedSource(sourceID)
    }

    func uninstall(sourceID: String) throws {
        guard let source = AgentSourceID(rawValue: sourceID) else {
            throw AgentIntegrationError.unsupportedSource(sourceID)
        }
        if let spec = hookSpec(for: source) {
            try jsonHooks.remove(
                at: spec.url,
                events: spec.events,
                command: hookCommand(for: source),
                layout: spec.layout
            )
            return
        }
        if source == .openCode || source == .amp {
            try uninstallPlugin(for: source)
            return
        }
        throw AgentIntegrationError.unsupportedSource(sourceID)
    }

    private func managedPluginStatus(
        for source: AgentSourceID
    ) -> AgentIntegrationStatus {
        guard
            let installedData = try? Data(contentsOf: pluginURL(for: source)),
            let content = String(data: installedData, encoding: .utf8),
            content.hasPrefix(Self.managedPluginMarker)
        else {
            return .notInstalled
        }
        guard
            let bundledURL = bundledPluginURL(for: source),
            let bundledData = try? Data(contentsOf: bundledURL)
        else {
            return .installed
        }
        return installedData == bundledData ? .installed : .updateAvailable
    }

    private func isManagedPlugin(for source: AgentSourceID) -> Bool {
        switch managedPluginStatus(for: source) {
        case .installed, .updateAvailable:
            return true
        case .builtIn, .notInstalled, .manual:
            return false
        }
    }

    private func installPlugin(for source: AgentSourceID) throws {
        let targetURL = pluginURL(for: source)
        if fileManager.fileExists(atPath: targetURL.path),
           !isManagedPlugin(for: source) {
            throw AgentIntegrationError.modifiedManagedPlugin(targetURL.path)
        }
        guard let sourceURL = bundledPluginURL(for: source) else {
            throw AgentIntegrationError.missingBundledIntegration(source.rawValue)
        }
        try fileManager.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: sourceURL, to: targetURL)
    }

    private func uninstallPlugin(for source: AgentSourceID) throws {
        let url = pluginURL(for: source)
        guard fileManager.fileExists(atPath: url.path) else { return }
        guard isManagedPlugin(for: source) else {
            throw AgentIntegrationError.modifiedManagedPlugin(url.path)
        }
        try fileManager.removeItem(at: url)
    }

    private func hookSpec(for source: AgentSourceID) -> HookSpec? {
        switch source {
        case .claudeCode:
            return HookSpec(
                source: source,
                url: homeURL.appendingPathComponent(".claude/settings.json"),
                events: ["UserPromptSubmit", "Stop", "StopFailure"],
                layout: .grouped(timeout: 3)
            )
        case .cursor:
            return HookSpec(
                source: source,
                url: homeURL.appendingPathComponent(".cursor/hooks.json"),
                events: ["beforeSubmitPrompt", "stop"],
                layout: .direct(timeout: 3)
            )
        case .geminiCLI:
            return HookSpec(
                source: source,
                url: homeURL.appendingPathComponent(".gemini/settings.json"),
                events: ["BeforeAgent", "AfterAgent"],
                layout: .grouped(timeout: 3_000)
            )
        case .codexDesktop, .openCode, .amp, .trae:
            return nil
        }
    }

    private func pluginURL(for source: AgentSourceID) -> URL {
        switch source {
        case .openCode:
            return homeURL.appendingPathComponent(
                ".config/opencode/plugins/vibebreak.js"
            )
        case .amp:
            return homeURL.appendingPathComponent(
                ".config/amp/plugins/vibebreak.js"
            )
        case .codexDesktop, .claudeCode, .cursor, .geminiCLI, .trae:
            return homeURL
        }
    }

    private func bundledPluginURL(for source: AgentSourceID) -> URL? {
        let filename: String
        switch source {
        case .openCode:
            filename = "opencode-vibebreak.js"
        case .amp:
            filename = "amp-vibebreak.js"
        case .codexDesktop, .claudeCode, .cursor, .geminiCLI, .trae:
            return nil
        }
        return resourceURL?
            .appendingPathComponent("Integrations", isDirectory: true)
            .appendingPathComponent(filename)
    }

    private func hookCommand(for source: AgentSourceID) -> String {
        let executable =
            "\"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit\""
        if source == .claudeCode {
            return executable
        }
        return "VIBEBREAK_SOURCE_ID=\(source.rawValue) \(executable)"
    }
}
