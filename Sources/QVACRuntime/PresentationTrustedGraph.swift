import Foundation

public struct PresentationTrustedGraph: Equatable, Sendable {
    public let nodes: [PresentationTrustedGraphNode]
    public let edges: [PresentationTrustedGraphEdge]

    public init(
        runtimeGraph: TrustedGraph,
        appIDFor: (NoteID) throws -> UUID
    ) throws {
        self.nodes = try runtimeGraph.nodes.map { node in
            PresentationTrustedGraphNode(
                id: try appIDFor(node.noteID),
                runtimeNoteID: node.noteID,
                title: node.title,
                kind: node.isPlaceholder ? .placeholderNote : .note
            )
        }
        self.edges = try runtimeGraph.edges.map { edge in
            PresentationTrustedGraphEdge(
                sourceID: try appIDFor(edge.sourceNoteID),
                targetID: try appIDFor(edge.targetNoteID),
                provenance: edge.provenance
            )
        }
    }

    public init(
        nodes: [PresentationTrustedGraphNode],
        edges: [PresentationTrustedGraphEdge]
    ) {
        self.nodes = nodes
        self.edges = edges
    }

    public func openIntent(for nodeID: UUID) -> PresentationTrustedGraphOpenIntent? {
        guard let node = nodes.first(where: { $0.id == nodeID }) else {
            return nil
        }
        switch node.kind {
        case .note:
            return .openExistingNote(node.id)
        case .placeholderNote:
            return .openPlaceholderForPromotion(node.id)
        }
    }
}

public struct PresentationTrustedGraphNode: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let runtimeNoteID: NoteID
    public let title: String
    public let kind: PresentationTrustedGraphNodeKind

    public init(
        id: UUID,
        runtimeNoteID: NoteID,
        title: String,
        kind: PresentationTrustedGraphNodeKind
    ) {
        self.id = id
        self.runtimeNoteID = runtimeNoteID
        self.title = title
        self.kind = kind
    }
}

public enum PresentationTrustedGraphNodeKind: Equatable, Sendable {
    case note
    case placeholderNote
}

public struct PresentationTrustedGraphEdge: Equatable, Sendable {
    public let sourceID: UUID
    public let targetID: UUID
    public let provenance: TrustedGraphEdgeProvenance

    public init(sourceID: UUID, targetID: UUID, provenance: TrustedGraphEdgeProvenance) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.provenance = provenance
    }
}

public enum PresentationTrustedGraphOpenIntent: Equatable, Sendable {
    case openExistingNote(UUID)
    case openPlaceholderForPromotion(UUID)
}

public struct PresentationTrustedGraphRelationshipScanPolicy: Equatable, Sendable {
    public let reviewUI: PresentationRelationshipScanReviewUI
    public let graphInteractions: PresentationTrustedGraphInteractionPolicy
    public let trustedGraphProvenances: [TrustedGraphEdgeProvenance]
    public let promotion: PresentationSuggestedRelationshipPromotionPolicy

    public static let firstFrontendIntegration = PresentationTrustedGraphRelationshipScanPolicy(
        reviewUI: .deferredFromFirstFrontendIntegration,
        graphInteractions: .navigationOnly,
        trustedGraphProvenances: [.explicitLink, .acceptedRelationship],
        promotion: .runtimePromotionCommandCreatesAcceptedRelationship
    )

    public init(
        reviewUI: PresentationRelationshipScanReviewUI,
        graphInteractions: PresentationTrustedGraphInteractionPolicy,
        trustedGraphProvenances: [TrustedGraphEdgeProvenance],
        promotion: PresentationSuggestedRelationshipPromotionPolicy
    ) {
        self.reviewUI = reviewUI
        self.graphInteractions = graphInteractions
        self.trustedGraphProvenances = trustedGraphProvenances
        self.promotion = promotion
    }

    public func shouldRenderInTrustedGraph(_: SuggestedRelationship) -> Bool {
        false
    }

    public func promotionCommand(for suggestedRelationship: SuggestedRelationship) -> RuntimeCommand {
        .promoteSuggestedRelationship(.init(suggestedRelationship: suggestedRelationship))
    }
}

public enum PresentationRelationshipScanReviewUI: Equatable, Sendable {
    case deferredFromFirstFrontendIntegration
}

public enum PresentationTrustedGraphInteractionPolicy: Equatable, Sendable {
    case navigationOnly
}

public enum PresentationSuggestedRelationshipPromotionPolicy: Equatable, Sendable {
    case runtimePromotionCommandCreatesAcceptedRelationship
}
