public struct TrustedGraph: Equatable, Sendable {
    public let nodes: [TrustedGraphNode]
    public let edges: [TrustedGraphEdge]

    public init(nodes: [TrustedGraphNode], edges: [TrustedGraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct TrustedGraphNode: Equatable, Sendable {
    public let noteID: NoteID
    public let title: String
    public let isPlaceholder: Bool

    public init(noteID: NoteID, title: String, isPlaceholder: Bool) {
        self.noteID = noteID
        self.title = title
        self.isPlaceholder = isPlaceholder
    }
}

public struct TrustedGraphEdge: Equatable, Hashable, Sendable {
    public let sourceNoteID: NoteID
    public let targetNoteID: NoteID
    public let provenance: TrustedGraphEdgeProvenance

    public init(sourceNoteID: NoteID, targetNoteID: NoteID, provenance: TrustedGraphEdgeProvenance) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.provenance = provenance
    }
}

public enum TrustedGraphEdgeProvenance: Equatable, Hashable, Sendable {
    case explicitLink
    case acceptedRelationship
}

public struct AcceptedRelationship: Equatable, Sendable {
    public let sourceNoteID: NoteID
    public let targetNoteID: NoteID

    public init(sourceNoteID: NoteID, targetNoteID: NoteID) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
    }
}
