import Foundation
import VibeBreakCore

@MainActor
final class AgentSourceController {
    var onEvent: ((LifecycleEvent) -> Void)?
    var onHealthChange: ((String, SourceHealth) -> Void)?
    var onStateInvalidated: ((String) -> Void)?

    private let sources: [String: AgentEventSource]
    private var subscriptions: [String: UUID] = [:]

    init(sources: [AgentEventSource]) {
        var keyed: [String: AgentEventSource] = [:]
        for source in sources {
            keyed[source.id] = source
        }
        self.sources = keyed
    }

    func applyEnabledSourceIDs(_ ids: [String]) {
        let nextEnabled = Set(ids)
        let previousEnabled = Set(subscriptions.keys)

        for removedID in previousEnabled.subtracting(nextEnabled) {
            subscriptions[removedID] = nil
            sources[removedID]?.stop()
            onStateInvalidated?(removedID)
        }

        for addedID in nextEnabled.subtracting(previousEnabled) {
            guard let source = sources[addedID] else { continue }
            let subscription = UUID()
            subscriptions[addedID] = subscription
            bind(source, subscription: subscription)
            source.start()
        }
    }

    func stopAll() {
        applyEnabledSourceIDs([])
    }

    private func bind(_ source: AgentEventSource, subscription: UUID) {
        source.onHealthChange = { [weak self, sourceID = source.id] health in
            DispatchQueue.main.async {
                guard let self, self.subscriptions[sourceID] == subscription else {
                    return
                }
                self.onHealthChange?(sourceID, health)
            }
        }
        source.onEvent = { [weak self, sourceID = source.id] event in
            DispatchQueue.main.async {
                guard let self, self.subscriptions[sourceID] == subscription else {
                    return
                }
                self.onEvent?(event)
            }
        }
        source.onStateInvalidated = { [weak self, sourceID = source.id] in
            DispatchQueue.main.async {
                guard let self, self.subscriptions[sourceID] == subscription else {
                    return
                }
                self.onStateInvalidated?(sourceID)
            }
        }
    }
}
