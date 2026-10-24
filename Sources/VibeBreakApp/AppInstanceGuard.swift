import Darwin
import Foundation

final class AppInstanceGuard {
    enum AcquireResult {
        case acquired
        case alreadyRunning
        case failed
    }

    static let showSettingsNotification = Notification.Name(
        "app.vibebreak.show-settings"
    )

    private var fileDescriptor: Int32 = -1

    deinit {
        if fileDescriptor >= 0 {
            flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
        }
    }

    func acquire() -> AcquireResult {
        let fileManager = FileManager.default
        let directory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("VibeBreak", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            return .failed
        }

        let lockURL = directory.appendingPathComponent("instance.lock")
        fileDescriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else { return .failed }

        if flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            return .acquired
        }

        close(fileDescriptor)
        fileDescriptor = -1
        return .alreadyRunning
    }

    static func requestSettingsFromRunningInstance() {
        DistributedNotificationCenter.default().postNotificationName(
            showSettingsNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
