import Foundation
import VibeBreakCore

@MainActor
final class AgentSourceController {
    var onEvent: ((LifecycleEvent) -> Void)?
    var onHealthChange: ((String, SourceHealth) -> Void)?

    private let sources: [String: AgentEventSource]
    private var enabledSourceIDs = Set<String>()

    init(sources: [AgentEventSource]) {
        var keyed: [String: AgentEventSource] = [:]
        for source in sources {
            keyed[source.id] = source
        }
        self.sources = keyed
    }

    func applyEnabledSourceIDs(_ ids: [String]) {
        let nextEnabled = Set(ids)

        for removedID in enabledSourceIDs.subtracting(nextEnabled) {
            sources[removedID]?.stop()
        }

        for addedID in nextEnabled.subtracting(enabledSourceIDs) {
            guard let source = sources[addedID] else { continue }
            bind(source)
            source.start()
        }

        enabledSourceIDs = nextEnabled
    }

    func stopAll() {
        for source in sources.values {
            source.stop()
        }
        enabledSourceIDs.removeAll()
    }

    private func bind(_ source: AgentEventSource) {
        source.onHealthChange = { [weak self, sourceID = source.id] health in
            DispatchQueue.main.async {
                self?.onHealthChange?(sourceID, health)
            }
        }
        source.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.onEvent?(event)
            }
        }
    }
}
