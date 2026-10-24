import Darwin
import Foundation
import VibeBreakCore

private struct ActiveBridgeTask: Codable {
    var threadID: String
    var taskID: String

    private enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case taskID = "task_id"
    }
}

private let inputData = FileHandle.standardInput.readDataToEndOfFile()
guard !inputData.isEmpty else {
    exit(0)
}

do {
    if let record = try? JSONDecoder().decode(BridgeEventRecord.self, from: inputData) {
        try append(record)
        writeHookResponse()
        exit(0)
    }

    let payload = try HookEventMapper.decode(data: inputData)
    let source = environment("VIBEBREAK_SOURCE_ID")
        ?? AgentSourceID.claudeCode.rawValue
    try emitHookIfNeeded(source: source, payload: payload)
    writeHookResponse()
} catch {
    FileHandle.standardError.write(
        Data("\(error.localizedDescription)\n".utf8)
    )
    exit(1)
}

private func emitHookIfNeeded(
    source: String,
    payload: HookEventPayload
) throws {
    guard let signal = try HookEventMapper.signal(
        sourceID: source,
        payload: payload
    ) else {
        return
    }

    switch signal {
    case .started(let mappedThreadID, let mappedTaskID):
        let threadID = environment("VIBEBREAK_THREAD_ID") ?? mappedThreadID
        let activeTask = ActiveBridgeTask(
            threadID: threadID,
            taskID: mappedTaskID ?? UUID().uuidString
        )
        try save(activeTask, source: source)
        try append(
            BridgeEventRecord(
                source: source,
                event: .started,
                threadID: activeTask.threadID,
                taskID: activeTask.taskID,
                timestamp: timestamp()
            )
        )

    case .finished(let mappedThreadID, let mappedTaskID, let reason):
        let threadID = environment("VIBEBREAK_THREAD_ID") ?? mappedThreadID
        let activeTask: ActiveBridgeTask
        if let mappedTaskID {
            activeTask = ActiveBridgeTask(
                threadID: threadID,
                taskID: mappedTaskID
            )
        } else if let savedTask = try loadActiveTask(
            source: source,
            threadID: threadID
        ) {
            activeTask = savedTask
        } else {
            return
        }
        try append(
            BridgeEventRecord(
                source: source,
                event: .finished,
                threadID: activeTask.threadID,
                taskID: activeTask.taskID,
                reason: reason,
                timestamp: timestamp()
            )
        )
        try removeActiveTask(source: source, threadID: threadID)
    }
}

private func append(_ record: BridgeEventRecord) throws {
    let fileURL = bridgeEventURL()
    let directory = fileURL.deletingLastPathComponent()
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

    let data = try BridgeEventParser.encodeLine(record)
    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }

    flock(handle.fileDescriptor, LOCK_EX)
    defer { flock(handle.fileDescriptor, LOCK_UN) }

    try handle.seekToEnd()
    try handle.write(contentsOf: data)
}

private func save(_ task: ActiveBridgeTask, source: String) throws {
    let stateURL = activeTaskURL(source: source, threadID: task.threadID)
    try FileManager.default.createDirectory(
        at: stateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(task)
    try data.write(to: stateURL, options: .atomic)
}

private func loadActiveTask(source: String, threadID: String) throws -> ActiveBridgeTask? {
    let stateURL = activeTaskURL(source: source, threadID: threadID)
    guard FileManager.default.fileExists(atPath: stateURL.path) else {
        return nil
    }
    let data = try Data(contentsOf: stateURL)
    return try JSONDecoder().decode(ActiveBridgeTask.self, from: data)
}

private func removeActiveTask(source: String, threadID: String) throws {
    let stateURL = activeTaskURL(source: source, threadID: threadID)
    if FileManager.default.fileExists(atPath: stateURL.path) {
        try FileManager.default.removeItem(at: stateURL)
    }
}

private func bridgeEventURL() -> URL {
    if let configured = environment("VIBEBREAK_BRIDGE_FILE") {
        return URL(fileURLWithPath: configured)
    }
    return applicationSupportURL()
        .appendingPathComponent("bridge", isDirectory: true)
        .appendingPathComponent("events.jsonl")
}

private func activeTaskURL(source: String, threadID: String) -> URL {
    applicationSupportURL()
        .appendingPathComponent("bridge", isDirectory: true)
        .appendingPathComponent("state", isDirectory: true)
        .appendingPathComponent("\(safeFilename(source))-\(safeFilename(threadID)).json")
}

private func applicationSupportURL() -> URL {
    FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0]
    .appendingPathComponent("VibeBreak", isDirectory: true)
}

private func safeFilename(_ value: String) -> String {
    let scalars = value.unicodeScalars.map { scalar -> Character in
        if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
            return Character(scalar)
        }
        return "_"
    }
    let result = String(scalars)
    return result.isEmpty ? "unknown" : result
}

private func timestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}

private func environment(_ key: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
        return nil
    }
    return value
}

private func writeHookResponse() {
    FileHandle.standardOutput.write(Data("{}\n".utf8))
}
