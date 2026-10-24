import Foundation

public enum AgentSourceID: String, CaseIterable, Codable, Sendable {
    case codexDesktop = "codex-desktop"
    case claudeCode = "claude-code"
    case cursor
    case geminiCLI = "gemini-cli"
    case openCode = "opencode"
    case amp
    case trae = "trae"

    public var usesBridge: Bool {
        self != .codexDesktop
    }
}

public enum CompletionAction: String, Codable, CaseIterable, Sendable {
    case openApplication
    case restorePreviousApplication
    case stay
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var enabled: Bool
    public var enabledSourceIdentifiers: [String]
    public var startApplicationBundleIdentifier: String
    public var completionAction: CompletionAction
    public var completionApplicationBundleIdentifier: String

    public init(
        schemaVersion: Int = currentSchemaVersion,
        enabled: Bool,
        enabledSourceIdentifiers: [String] = [AgentSourceID.codexDesktop.rawValue],
        startApplicationBundleIdentifier: String,
        completionAction: CompletionAction,
        completionApplicationBundleIdentifier: String
    ) {
        self.schemaVersion = schemaVersion
        self.enabled = enabled
        self.enabledSourceIdentifiers = Self.normalizedSourceIdentifiers(
            enabledSourceIdentifiers
        )
        self.startApplicationBundleIdentifier = startApplicationBundleIdentifier
        self.completionAction = completionAction
        self.completionApplicationBundleIdentifier = completionApplicationBundleIdentifier
    }

    public static let initial = AppSettings(
        enabled: false,
        enabledSourceIdentifiers: [AgentSourceID.codexDesktop.rawValue],
        startApplicationBundleIdentifier: "",
        completionAction: .openApplication,
        completionApplicationBundleIdentifier: "com.openai.codex"
    )

    public var isConfigured: Bool {
        hasEnabledSources
            && !startApplicationBundleIdentifier.isEmpty
            && (completionAction != .openApplication
                || !completionApplicationBundleIdentifier.isEmpty)
    }

    public var hasEnabledSources: Bool {
        !enabledSourceIdentifiers.isEmpty
    }

    public func sourceIsEnabled(_ sourceID: String) -> Bool {
        enabledSourceIdentifiers.contains(sourceID)
    }

    public mutating func setSource(_ sourceID: String, enabled: Bool) {
        var identifiers = enabledSourceIdentifiers
        if enabled {
            identifiers.append(sourceID)
        } else {
            identifiers.removeAll { $0 == sourceID }
        }
        enabledSourceIdentifiers = Self.normalizedSourceIdentifiers(identifiers)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case enabled
        case enabledSourceIdentifiers
        case startApplicationBundleIdentifier
        case completionAction
        case completionApplicationBundleIdentifier

        // Version 0 keys used by the original proof of concept.
        case targetBundleId
        case returnBundleId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .schemaVersion
        ) ?? Self.currentSchemaVersion
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        enabledSourceIdentifiers = Self.normalizedSourceIdentifiers(
            try container.decodeIfPresent(
                [String].self,
                forKey: .enabledSourceIdentifiers
            ) ?? [AgentSourceID.codexDesktop.rawValue]
        )

        startApplicationBundleIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .startApplicationBundleIdentifier
        ) ?? container.decodeIfPresent(
            String.self,
            forKey: .targetBundleId
        ) ?? ""

        completionAction = try container.decodeIfPresent(
            CompletionAction.self,
            forKey: .completionAction
        ) ?? .openApplication

        completionApplicationBundleIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .completionApplicationBundleIdentifier
        ) ?? container.decodeIfPresent(
            String.self,
            forKey: .returnBundleId
        ) ?? "com.openai.codex"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(
            enabledSourceIdentifiers,
            forKey: .enabledSourceIdentifiers
        )
        try container.encode(
            startApplicationBundleIdentifier,
            forKey: .startApplicationBundleIdentifier
        )
        try container.encode(completionAction, forKey: .completionAction)
        try container.encode(
            completionApplicationBundleIdentifier,
            forKey: .completionApplicationBundleIdentifier
        )
    }

    private static func normalizedSourceIdentifiers(
        _ identifiers: [String]
    ) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { identifier in
            guard !identifier.isEmpty, !seen.contains(identifier) else {
                return false
            }
            seen.insert(identifier)
            return true
        }
    }
}
