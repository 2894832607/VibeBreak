import Foundation
import VibeBreakCore

enum SettingsStoreError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "设置文件版本 \(version) 高于当前应用支持的版本"
        }
    }
}

final class SettingsStore {
    private let fileManager: FileManager
    private let settingsURL: URL
    private let legacySettingsURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        settingsURL = applicationSupport
            .appendingPathComponent("VibeBreak", isDirectory: true)
            .appendingPathComponent("settings.json")
        legacySettingsURL = applicationSupport
            .appendingPathComponent("Douyin Break", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    var currentURL: URL {
        settingsURL
    }

    func load() throws -> AppSettings {
        if fileManager.fileExists(atPath: settingsURL.path) {
            let settings = try decode(at: settingsURL)
            if settings.schemaVersion < AppSettings.currentSchemaVersion {
                try save(settings)
            }
            return settings
        }

        if fileManager.fileExists(atPath: legacySettingsURL.path) {
            let migrated = try decode(at: legacySettingsURL)
            try save(migrated)
            return migrated
        }

        let initial = AppSettings.initial
        try save(initial)
        return initial
    }

    func save(_ settings: AppSettings) throws {
        let directory = settingsURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    private func decode(at url: URL) throws -> AppSettings {
        let data = try Data(contentsOf: url)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        guard settings.schemaVersion <= AppSettings.currentSchemaVersion else {
            throw SettingsStoreError.unsupportedSchema(settings.schemaVersion)
        }
        return settings
    }
}
