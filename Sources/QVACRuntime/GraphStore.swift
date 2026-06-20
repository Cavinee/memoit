protocol GraphStore: AnyObject {
    func replaceExplicitLinks(from sourceNoteID: NoteID, with explicitLinks: [ExplicitLink]) throws
    func explicitLinks(from sourceNoteID: NoteID) throws -> [ExplicitLink]
    func sourceNoteIDsWithExplicitLinks(to targetNoteID: NoteID) throws -> [NoteID]
    func explicitLinkTargets(from sourceNoteID: NoteID) throws -> [NoteID]
    func removeExplicitLinks(involving noteID: NoteID) throws
    func backlinks(to targetNoteID: NoteID, sourceNote: (NoteID) throws -> Note?) throws -> [Backlink]
    func createAcceptedRelationship(sourceNoteID: NoteID, targetNoteID: NoteID) throws -> AcceptedRelationship
    func acceptedRelationshipTargets(from sourceNoteID: NoteID) throws -> [NoteID]
    func listAcceptedRelationships() throws -> [AcceptedRelationship]
    func trustedGraph(notes: [Note]) throws -> TrustedGraph
}

final class InMemoryGraphStore: GraphStore {
    private var explicitLinksBySourceNoteID: [NoteID: [ExplicitLink]] = [:]
    private var acceptedRelationships: [AcceptedRelationship] = []

    func replaceExplicitLinks(from sourceNoteID: NoteID, with explicitLinks: [ExplicitLink]) throws {
        explicitLinksBySourceNoteID[sourceNoteID] = explicitLinks
    }

    func explicitLinks(from sourceNoteID: NoteID) throws -> [ExplicitLink] {
        explicitLinksBySourceNoteID[sourceNoteID] ?? []
    }

    func sourceNoteIDsWithExplicitLinks(to targetNoteID: NoteID) throws -> [NoteID] {
        explicitLinksBySourceNoteID.compactMap { sourceNoteID, links in
            links.contains { $0.targetNoteID == targetNoteID } ? sourceNoteID : nil
        }
    }

    func explicitLinkTargets(from sourceNoteID: NoteID) throws -> [NoteID] {
        var seen = Set<NoteID>()
        return (explicitLinksBySourceNoteID[sourceNoteID] ?? []).compactMap { link in
            seen.insert(link.targetNoteID).inserted ? link.targetNoteID : nil
        }
    }

    func removeExplicitLinks(involving noteID: NoteID) throws {
        explicitLinksBySourceNoteID[noteID] = nil
        explicitLinksBySourceNoteID = explicitLinksBySourceNoteID.mapValues { links in
            links.filter { $0.targetNoteID != noteID }
        }
    }

    func backlinks(to targetNoteID: NoteID, sourceNote: (NoteID) throws -> Note?) throws -> [Backlink] {
        try explicitLinksBySourceNoteID.values.flatMap { links in
            try links.compactMap { link in
                guard link.targetNoteID == targetNoteID, let source = try sourceNote(link.sourceNoteID) else {
                    return nil
                }

                return Backlink(
                    sourceNoteID: source.id,
                    sourceNoteTitle: source.title,
                    targetNoteID: link.targetNoteID,
                    snippet: link.snippet
                )
            }
        }
    }

    func createAcceptedRelationship(sourceNoteID: NoteID, targetNoteID: NoteID) throws -> AcceptedRelationship {
        let relationship = AcceptedRelationship(sourceNoteID: sourceNoteID, targetNoteID: targetNoteID)
        acceptedRelationships.append(relationship)
        return relationship
    }

    func acceptedRelationshipTargets(from sourceNoteID: NoteID) throws -> [NoteID] {
        var seen = Set<NoteID>()
        return acceptedRelationships.compactMap { relationship in
            guard relationship.sourceNoteID == sourceNoteID else {
                return nil
            }

            return seen.insert(relationship.targetNoteID).inserted ? relationship.targetNoteID : nil
        }
    }

    func listAcceptedRelationships() throws -> [AcceptedRelationship] {
        acceptedRelationships
    }

    func trustedGraph(notes: [Note]) throws -> TrustedGraph {
        let activeNoteIDs = Set(notes.map(\.id))
        var seenEdges = Set<TrustedGraphEdge>()
        var edges: [TrustedGraphEdge] = []

        func appendEdge(_ edge: TrustedGraphEdge) {
            if seenEdges.insert(edge).inserted {
                edges.append(edge)
            }
        }

        for note in notes {
            for link in explicitLinksBySourceNoteID[note.id] ?? [] where activeNoteIDs.contains(link.targetNoteID) {
                appendEdge(TrustedGraphEdge(
                    sourceNoteID: link.sourceNoteID,
                    targetNoteID: link.targetNoteID,
                    provenance: .explicitLink
                ))
            }
        }

        for relationship in acceptedRelationships where activeNoteIDs.contains(relationship.sourceNoteID) && activeNoteIDs.contains(relationship.targetNoteID) {
            appendEdge(TrustedGraphEdge(
                sourceNoteID: relationship.sourceNoteID,
                targetNoteID: relationship.targetNoteID,
                provenance: .acceptedRelationship
            ))
        }

        return TrustedGraph(
            nodes: notes.map { note in
                TrustedGraphNode(noteID: note.id, title: note.title, isPlaceholder: note.isPlaceholder)
            },
            edges: edges
        )
    }
}
