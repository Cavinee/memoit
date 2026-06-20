import Foundation
import Combine
import QVACRuntime

@MainActor
final class GraphViewModel: ObservableObject {
    @Published var graph = PresentationTrustedGraph(nodes: [], edges: [])
    @Published var selectedNodeID: UUID?

    private let runtimeService: KnowledgeRuntimeService

    init(runtimeService: KnowledgeRuntimeService? = nil) {
        self.runtimeService = runtimeService ?? .shared
    }

    var selectedNode: PresentationTrustedGraphNode? {
        guard let selectedNodeID else { return nil }
        return graph.nodes.first { $0.id == selectedNodeID }
    }

    func refresh() {
        graph = runtimeService.trustedGraph()
        if let selectedNodeID, !graph.nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = nil
        }
    }

    func select(_ node: PresentationTrustedGraphNode) {
        selectedNodeID = node.id
    }

    func openSelectedNote() -> Note? {
        guard let selectedNodeID, let intent = graph.openIntent(for: selectedNodeID) else {
            return nil
        }

        switch intent {
        case .openExistingNote(let noteID), .openPlaceholderForPromotion(let noteID):
            return runtimeService.note(id: noteID)
        }
    }
}
