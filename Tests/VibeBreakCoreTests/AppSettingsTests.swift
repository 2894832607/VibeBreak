import Foundation
import Testing
@testable import VibeBreakCore

struct AppSettingsTests {
    @Test func decodesLegacyConfiguration() throws {
        let data = Data(
            """
            {
              "enabled": true,
              "targetBundleId": "com.bytedance.douyin.desktop",
              "returnBundleId": "com.openai.codex"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.enabled)
        #expect(
            settings.enabledSourceIdentifiers
                == [AgentSourceID.codexDesktop.rawValue]
        )
        #expect(
            settings.startApplicationBundleIdentifier
                == "com.bytedance.douyin.desktop"
        )
        #expect(settings.completionAction == .openApplication)
        #expect(
            settings.completionApplicationBundleIdentifier
                == "com.openai.codex"
        )
    }

    @Test func encodesOnlyCurrentSchemaKeys() throws {
        let settings = AppSettings(
            enabled: true,
            startApplicationBundleIdentifier: "app.start",
            completionAction: .stay,
            completionApplicationBundleIdentifier: ""
        )

        let data = try JSONEncoder().encode(settings)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(
            object["schemaVersion"] as? Int
                == AppSettings.currentSchemaVersion
        )
        #expect(
            object["startApplicationBundleIdentifier"] as? String
                == "app.start"
        )
        #expect(
            object["enabledSourceIdentifiers"] as? [String]
                == [AgentSourceID.codexDesktop.rawValue]
        )
        #expect(object["targetBundleId"] == nil)
        #expect(object["returnBundleId"] == nil)
    }

    @Test func normalizesSourceIdentifiers() {
        var settings = AppSettings(
            enabled: true,
            enabledSourceIdentifiers: [
                AgentSourceID.codexDesktop.rawValue,
                AgentSourceID.codexDesktop.rawValue,
                "",
                AgentSourceID.trae.rawValue,
            ],
            startApplicationBundleIdentifier: "app.start",
            completionAction: .stay,
            completionApplicationBundleIdentifier: ""
        )

        #expect(
            settings.enabledSourceIdentifiers == [
                AgentSourceID.codexDesktop.rawValue,
                AgentSourceID.trae.rawValue,
            ]
        )

        settings.setSource(AgentSourceID.claudeCode.rawValue, enabled: true)
        settings.setSource(AgentSourceID.codexDesktop.rawValue, enabled: false)

        #expect(
            settings.enabledSourceIdentifiers == [
                AgentSourceID.trae.rawValue,
                AgentSourceID.claudeCode.rawValue,
            ]
        )
    }
}
