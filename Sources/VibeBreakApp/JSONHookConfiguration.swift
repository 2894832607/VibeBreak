import Foundation

enum JSONHookLayout {
    case grouped(timeout: Int)
    case direct(timeout: Int)
}

struct JSONHookConfiguration {
    let fileManager: FileManager

    func containsCommand(
        at url: URL,
        events: [String],
        command: String
    ) -> Bool {
        guard
            let root = try? readObject(at: url),
            let hooks = root["hooks"] as? [String: Any]
        else {
            return false
        }
        return events.allSatisfy { event in
            guard let definitions = hooks[event] as? [Any] else {
                return false
            }
            return containsCommand(definitions, command: command)
        }
    }

    func install(
        at url: URL,
        events: [String],
        command: String,
        layout: JSONHookLayout
    ) throws {
        var root = try readObject(at: url)
        var hooks = try dictionary(root["hooks"], path: "\(url.path):hooks")

        for event in events {
            var definitions = try array(
                hooks[event],
                path: "\(url.path):hooks.\(event)"
            )
            guard !containsCommand(definitions, command: command) else {
                continue
            }
            definitions.append(definition(command: command, layout: layout))
            hooks[event] = definitions
        }

        if case .direct = layout {
            root["version"] = root["version"] ?? 1
        }
        root["hooks"] = hooks
        try writeObject(root, to: url)
    }

    func remove(
        at url: URL,
        events: [String],
        command: String,
        layout: JSONHookLayout
    ) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        var root = try readObject(at: url)
        var hooks = try dictionary(root["hooks"], path: "\(url.path):hooks")

        for event in events {
            let definitions = try array(
                hooks[event],
                path: "\(url.path):hooks.\(event)"
            )
            let remaining: [Any]
            switch layout {
            case .grouped:
                remaining = definitions.compactMap {
                    removingGroupedCommand($0, command: command)
                }
            case .direct:
                remaining = definitions.filter {
                    !containsCommand($0, command: command)
                }
            }
            hooks[event] = remaining.isEmpty ? nil : remaining
        }

        root["hooks"] = hooks
        try writeObject(root, to: url)
    }

    private func definition(
        command: String,
        layout: JSONHookLayout
    ) -> [String: Any] {
        switch layout {
        case .grouped(let timeout):
            return [
                "hooks": [
                    [
                        "type": "command",
                        "command": command,
                        "timeout": timeout,
                    ],
                ],
            ]
        case .direct(let timeout):
            return [
                "command": command,
                "timeout": timeout,
            ]
        }
    }

    private func removingGroupedCommand(
        _ value: Any,
        command: String
    ) -> Any? {
        guard var group = value as? [String: Any] else { return value }
        guard let definitions = group["hooks"] as? [Any] else { return value }
        let remaining = definitions.filter {
            !containsCommand($0, command: command)
        }
        guard !remaining.isEmpty else { return nil }
        group["hooks"] = remaining
        return group
    }

    private func readObject(at url: URL) throws -> [String: Any] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard
            let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw AgentIntegrationError.invalidConfiguration(url.path)
        }
        return object
    }

    private func writeObject(_ object: [String: Any], to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }

    private func dictionary(
        _ value: Any?,
        path: String
    ) throws -> [String: Any] {
        guard let value else { return [:] }
        guard let dictionary = value as? [String: Any] else {
            throw AgentIntegrationError.invalidConfiguration(path)
        }
        return dictionary
    }

    private func array(_ value: Any?, path: String) throws -> [Any] {
        guard let value else { return [] }
        guard let array = value as? [Any] else {
            throw AgentIntegrationError.invalidConfiguration(path)
        }
        return array
    }

    private func containsCommand(_ value: Any, command: String) -> Bool {
        if let dictionary = value as? [String: Any] {
            if dictionary["command"] as? String == command {
                return true
            }
            return dictionary.values.contains {
                containsCommand($0, command: command)
            }
        }
        if let array = value as? [Any] {
            return array.contains { containsCommand($0, command: command) }
        }
        return false
    }
}
