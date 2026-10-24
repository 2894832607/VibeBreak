import Foundation
import Testing
@testable import VibeBreakApp
import VibeBreakCore

struct AgentIntegrationManagerTests {
    @Test func partialCursorIntegrationIsNotInstalled() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let configURL = rootURL.appendingPathComponent(".cursor/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let command = managedCommand(for: AgentSourceID.cursor.rawValue)
        let object: [String: Any] = [
            "version": 1,
            "hooks": [
                "beforeSubmitPrompt": [
                    ["command": command, "timeout": 3],
                ],
            ],
        ]
        try JSONSerialization.data(
            withJSONObject: object,
            options: .prettyPrinted
        ).write(to: configURL)

        let manager = AgentIntegrationManager(
            homeURL: rootURL,
            resourceURL: nil
        )

        #expect(
            manager.status(for: AgentSourceID.cursor.rawValue)
                == .notInstalled
        )

        try manager.install(sourceID: AgentSourceID.cursor.rawValue)
        #expect(
            manager.status(for: AgentSourceID.cursor.rawValue) == .installed
        )
        let installed = try jsonObject(at: configURL)
        #expect(commandCount(in: installed, command: command) == 2)
    }

    @Test func cursorInstallIsIdempotentAndPreservesExistingHooks() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let configURL = rootURL.appendingPathComponent(".cursor/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            {
              "version": 1,
              "hooks": {
                "afterFileEdit": [
                  {"command": "existing-hook"}
                ]
              }
            }
            """.utf8
        ).write(to: configURL)

        let manager = AgentIntegrationManager(
            homeURL: rootURL,
            resourceURL: nil
        )
        try manager.install(sourceID: AgentSourceID.cursor.rawValue)
        try manager.install(sourceID: AgentSourceID.cursor.rawValue)

        let root = try jsonObject(at: configURL)
        let hooks = try #require(root["hooks"] as? [String: Any])
        #expect(commandCount(in: hooks, command: "existing-hook") == 1)
        #expect(
            commandCount(
                in: hooks,
                command: managedCommand(for: AgentSourceID.cursor.rawValue)
            ) == 2
        )
        #expect(
            manager.status(for: AgentSourceID.cursor.rawValue) == .installed
        )

        try manager.uninstall(sourceID: AgentSourceID.cursor.rawValue)

        let updatedRoot = try jsonObject(at: configURL)
        let updatedHooks = try #require(
            updatedRoot["hooks"] as? [String: Any]
        )
        #expect(commandCount(in: updatedHooks, command: "existing-hook") == 1)
        #expect(
            commandCount(
                in: updatedHooks,
                command: managedCommand(for: AgentSourceID.cursor.rawValue)
            ) == 0
        )
    }

    @Test func managedPluginWillNotOverwriteUserFile() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let pluginURL = rootURL.appendingPathComponent(
            ".config/opencode/plugins/vibebreak.js"
        )
        try FileManager.default.createDirectory(
            at: pluginURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("export const userPlugin = true\n".utf8).write(to: pluginURL)

        let manager = AgentIntegrationManager(
            homeURL: rootURL,
            resourceURL: rootURL
        )

        #expect(throws: (any Error).self) {
            try manager.install(sourceID: AgentSourceID.openCode.rawValue)
        }
    }

    @Test func outdatedManagedPluginCanBeUpdated() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let resourceURL = rootURL.appendingPathComponent(
            "resources",
            isDirectory: true
        )
        let bundledURL = resourceURL.appendingPathComponent(
            "Integrations/opencode-vibebreak.js"
        )
        let pluginURL = rootURL.appendingPathComponent(
            ".config/opencode/plugins/vibebreak.js"
        )
        try FileManager.default.createDirectory(
            at: bundledURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: pluginURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let marker = "// VibeBreak managed integration v1\n"
        try Data("\(marker)current\n".utf8).write(to: bundledURL)
        try Data("\(marker)old\n".utf8).write(to: pluginURL)

        let manager = AgentIntegrationManager(
            homeURL: rootURL,
            resourceURL: resourceURL
        )

        #expect(
            manager.status(for: AgentSourceID.openCode.rawValue)
                == .updateAvailable
        )

        try manager.install(sourceID: AgentSourceID.openCode.rawValue)

        #expect(
            manager.status(for: AgentSourceID.openCode.rawValue) == .installed
        )
        #expect(try Data(contentsOf: pluginURL) == Data(contentsOf: bundledURL))
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private func managedCommand(for sourceID: String) -> String {
        "VIBEBREAK_SOURCE_ID=\(sourceID) " +
            "\"$HOME/Applications/VibeBreak.app/Contents/MacOS/vibebreak-bridge-emit\""
    }

    private func commandCount(in value: Any, command: String) -> Int {
        if let dictionary = value as? [String: Any] {
            return (dictionary["command"] as? String == command ? 1 : 0)
                + dictionary.values.reduce(0) {
                    $0 + commandCount(in: $1, command: command)
                }
        }
        if let array = value as? [Any] {
            return array.reduce(0) {
                $0 + commandCount(in: $1, command: command)
            }
        }
        return 0
    }
}
