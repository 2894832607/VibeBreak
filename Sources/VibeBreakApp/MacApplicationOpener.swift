import AppKit
import Foundation
import VibeBreakCore

enum ApplicationOpenError: LocalizedError {
    case notInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let bundleIdentifier):
            return "未找到应用 \(bundleIdentifier)"
        case .launchFailed(let detail):
            return detail
        }
    }
}

final class MacApplicationOpener: ApplicationOpening {
    var frontmostApplicationBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func openApplication(bundleIdentifier: String) throws {
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) != nil else {
            throw ApplicationOpenError.notInstalled(bundleIdentifier)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleIdentifier]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ApplicationOpenError.launchFailed(
                    "系统无法打开 \(bundleIdentifier)"
                )
            }
        } catch {
            if let applicationError = error as? ApplicationOpenError {
                throw applicationError
            }
            throw ApplicationOpenError.launchFailed(error.localizedDescription)
        }
    }
}
