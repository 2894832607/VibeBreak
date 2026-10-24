import Foundation
import Testing
@testable import VibeBreakApp
import VibeBreakCore

struct AgentIntegrationManagerTests {
    @Test func codexInstallPreservesHooksAndOriginalBackup() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let configURL = rootURL.appendingPathComponent("isolated/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let original = Data(
            """
            {"custom":true,"hooks":{
              "Stop":[{"matcher":"existing","hooks":[{"type":"command","command":"existing-stop"}]}],
              "SessionEnd":[{"hooks":[{"type":"command","command":"existing-end"}]}]
            }}
            """.utf8
        )
        try original.write(to: configURL)
        let manager = AgentIntegrationManager(
            homeURL: rootURL,
            codexHooksURL: configURL,
            environment: [:],
            resourceURL: nil
        )
        #expect(manager.status(for: "codex-hooks") == .notInstalled)
        try manager.install(sourceID: "codex-hooks")
        try manager.install(sourceID: "codex-hooks")
        #expect(manager.status(for: "codex-hooks") == .installed)
        let command = managedCommand(for: "codex-hooks")
        let installed = try jsonObject(at: configURL)
        #expect(commandCount(in: installed, command: command) == 3)
        #expect(installed["custom"] as? Bool == true)
        let hooks = try #require(installed["hooks"] as? [String: Any])
        for event in ["UserPromptSubmit", "Stop", "Interrupt"] {
            let groups = try #require(hooks[event] as? [[String: Any]])
            let group = try #require(groups.last)
            let definitions = try #require(group["hooks"] as? [[String: Any]])
            #expect(definitions.first?["type"] as? String == "command")
            #expect(definitions.first?["timeout"] as? Int == 3)
        }
        let backupURL = configURL.appendingPathExtension("vibebreak-backup")
        #expect(try Data(contentsOf: backupURL) == original)
        try manager.uninstall(sourceID: "codex-hooks")
        let removed = try jsonObject(at: configURL)
        #expect(commandCount(in: removed, command: command) == 0)
        #expect(commandCount(in: removed, command: "existing-stop") == 1)
        #expect(commandCount(in: removed, command: "existing-end") == 1)
        #expect(removed["custom"] as? Bool == true)
        let remainingHooks = try #require(removed["hooks"] as? [String: Any])
        let stopGroups = try #require(remainingHooks["Stop"] as? [[String: Any]])
        #expect(stopGroups.first?["matcher"] as? String == "existing")
        try manager.install(sourceID: "codex-hooks")
        #expect(try Data(contentsOf: backupURL) == original)
        #expect(!FileManager.default.fileExists(
            atPath: rootURL.appendingPathComponent(".codex/hooks.json").path
        ))
    }

    @Test func codexHookPathRespectsEnvironmentAndDefaults() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let codexHome = rootURL.appendingPathComponent("custom-codex-home")
        let custom = AgentIntegrationManager(
            homeURL: rootURL,
            environment: ["CODEX_HOME": codexHome.path],
            resourceURL: nil
        )
        try custom.install(sourceID: "codex-hooks")
        #expect(FileManager.default.fileExists(
            atPath: codexHome.appendingPathComponent("hooks.json").path
        ))
        let fallback = AgentIntegrationManager(
            homeURL: rootURL, environment: [:], resourceURL: nil
        )
        #expect(fallback.status(for: "codex-hooks") == .notInstalled)
        try fallback.install(sourceID: "codex-hooks")
        #expect(FileManager.default.fileExists(
            atPath: rootURL.appendingPathComponent(".codex/hooks.json").path
        ))
    }

    @Test func codexUninstallBacksUpBeforeFirstModification() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let configURL = rootURL.appendingPathComponent("hooks.json")
        let command = managedCommand(for: "codex-hooks")
        let original = try JSONSerialization.data(withJSONObject: [
            "hooks": ["Stop": [["hooks": [
                ["type": "command", "command": command],
                ["type": "command", "command": "keep"],
            ]]]],
        ])
        try original.write(to: configURL)
        let manager = AgentIntegrationManager(
            homeURL: rootURL, codexHooksURL: configURL,
            environment: [:], resourceURL: nil
        )
        try manager.uninstall(sourceID: "codex-hooks")
        #expect(try Data(contentsOf:
            configURL.appendingPathExtension("vibebreak-backup")) == original)
        #expect(commandCount(in: try jsonObject(at: configURL), command: "keep") == 1)
    }

    @Test func invalidCodexConfigIsNotOverwritten() throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let configURL = rootURL.appendingPathComponent("hooks.json")
        let original = Data(#"{"hooks":{"Stop":"invalid"}}"#.utf8)
        try original.write(to: configURL)
        let manager = AgentIntegrationManager(
            homeURL: rootURL, codexHooksURL: configURL,
            environment: [:], resourceURL: nil
        )
        #expect(throws: (any Error).self) {
            try manager.install(sourceID: "codex-hooks")
        }
        #expect(try Data(contentsOf: configURL) == original)
        #expect(!FileManager.default.fileExists(
            atPath: configURL.appendingPathExtension("vibebreak-backup").path
        ))
    }

    @Test func codexDescriptorExplainsExperimentalManualOptIn() throws {
        let url = URL(fileURLWithPath: "/unused")
        let descriptors = AgentSourceDescriptor.builtIn(
            codexDatabaseURL: url, bridgeEventURL: url
        )
        let descriptor = try #require(descriptors.first { $0.id == "codex-hooks" })
        #expect(descriptor.detail.contains("实验性"))
        #expect(descriptor.detail.contains("手动"))
        #expect(descriptor.detail.contains("Stop"))
        #expect(descriptor.detail.contains("续跑"))
        #expect(descriptor.dataURL == url)
    }

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
