import Foundation

public final class JSONLBridgeEventSource: AgentEventSource {
    public let id: String
    public var onEvent: ((LifecycleEvent) -> Void)?
    public var onHealthChange: ((SourceHealth) -> Void)?
    public var onStateInvalidated: (() -> Void)?

    private let fileURL: URL
    private let pollInterval: TimeInterval
    private let queue: DispatchQueue

    private var timer: DispatchSourceTimer?
    private var offset: UInt64 = 0
    private var offsetInitialized = false
    private var pendingText = ""
    private var health: SourceHealth = .stopped

    public init(
        id: String,
        fileURL: URL,
        pollInterval: TimeInterval = 0.1
    ) {
        self.id = id
        self.fileURL = fileURL
        self.pollInterval = pollInterval
        queue = DispatchQueue(label: "app.vibebreak.bridge-source.\(id)")
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            self.updateHealth(.connecting)
            guard self.prepareFile() else { return }
            self.initializeOffset()
            self.updateHealth(.monitoring)

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(
                deadline: .now() + self.pollInterval,
                repeating: self.pollInterval,
                leeway: .milliseconds(20)
            )
            timer.setEventHandler { [weak self] in
                self?.poll()
            }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            offset = 0
            offsetInitialized = false
            pendingText = ""
            updateHealth(.stopped)
        }
    }

    private func prepareFile() -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(
                    atPath: fileURL.path,
                    contents: nil,
                    attributes: [.posixPermissions: 0o600]
                )
            }
            return true
        } catch {
            updateHealth(.failed("Bridge 事件文件不可写：\(error.localizedDescription)"))
            return false
        }
    }

    private func initializeOffset() {
        guard !offsetInitialized else { return }
        offset = fileSize() ?? 0
        offsetInitialized = true
    }

    private func poll() {
        guard prepareFile() else { return }
        guard let size = fileSize() else {
            updateHealth(.failed("无法读取 Bridge 事件文件"))
            return
        }
        guard size >= offset else {
            offset = size
            pendingText = ""
            onStateInvalidated?()
            updateHealth(.monitoring)
            return
        }
        guard size > offset else { return }
        drainNewBytes()
    }

    private func drainNewBytes() {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            try handle.seek(toOffset: offset)
            let data = handle.readDataToEndOfFile()
            offset += UInt64(data.count)
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else {
                updateHealth(.failed("Bridge 事件文件包含非 UTF-8 数据"))
                return
            }
            consume(text)
        } catch {
            updateHealth(.failed("无法读取 Bridge 事件：\(error.localizedDescription)"))
        }
    }

    private func consume(_ text: String) {
        pendingText += text
        let hasCompleteTrailingLine = pendingText.hasSuffix("\n")
        var lines = pendingText.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        if hasCompleteTrailingLine {
            pendingText = ""
        } else {
            pendingText = lines.popLast() ?? ""
        }

        for line in lines where !line.isEmpty {
            handle(line)
        }
    }

    private func handle(_ line: String) {
        do {
            let record = try BridgeEventParser.decode(line: line)
            if let event = BridgeEventParser.lifecycleEvent(
                from: record,
                acceptedSourceID: id
            ) {
                onEvent?(event)
            }
            if health != .monitoring {
                updateHealth(.monitoring)
            }
        } catch {
            updateHealth(.failed(error.localizedDescription))
        }
    }

    private func fileSize() -> UInt64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: fileURL.path
            ),
            let size = attributes[.size] as? UInt64
        else {
            return nil
        }
        return size
    }

    private func updateHealth(_ newValue: SourceHealth) {
        guard health != newValue else { return }
        health = newValue
        onHealthChange?(newValue)
    }
}
