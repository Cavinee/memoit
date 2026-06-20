import Foundation

public enum RuntimeCoreHarness {
    public static func makeInMemory(aiRuntimeAdapter: any AIRuntimeAdapter = FakeAIRuntimeAdapter(), clock: @escaping () -> Date = Date.init) -> OnDeviceKnowledgeRuntime {
        OnDeviceKnowledgeRuntime(
            noteStore: InMemoryNoteStore(clock: clock),
            graphStore: InMemoryGraphStore(),
            linkEngine: MarkdownLinkEngine(),
            userSearchIndex: UserSearchIndex(),
            modelInventory: ModelInventoryStore(),
            aiRuntimeAdapter: aiRuntimeAdapter,
            aiSessionHistoryStore: AISessionHistoryStore(),
            savedAIResponseStore: SavedAIResponseStore(),
            aiOperationStore: AIOperationStore(),
            clock: clock
        )
    }

    public static func makeSQLiteBacked(storageURL: URL, aiRuntimeAdapter: any AIRuntimeAdapter = FakeAIRuntimeAdapter(), clock: @escaping () -> Date = Date.init) throws -> OnDeviceKnowledgeRuntime {
        let noteStore = try SQLiteNoteStore(storageURL: storageURL, clock: clock)
        let graphStore = try SQLiteGraphStore(storageURL: storageURL)
        if try graphStore.isEmpty() {
            try backfillExplicitLinksFromStoredNoteBodies(noteStore: noteStore, graphStore: graphStore)
        }
        let userSearchIndex = UserSearchIndex()
        userSearchIndex.rebuild(from: try noteStore.listNotes())

        return OnDeviceKnowledgeRuntime(
            noteStore: noteStore,
            graphStore: graphStore,
            linkEngine: MarkdownLinkEngine(),
            userSearchIndex: userSearchIndex,
            modelInventory: ModelInventoryStore(),
            aiRuntimeAdapter: aiRuntimeAdapter,
            aiSessionHistoryStore: AISessionHistoryStore(),
            savedAIResponseStore: SavedAIResponseStore(),
            aiOperationStore: AIOperationStore(),
            clock: clock
        )
    }

    private static func backfillExplicitLinksFromStoredNoteBodies(noteStore: NoteStore, graphStore: GraphStore) throws {
        let linkEngine = MarkdownLinkEngine()
        let notes = try noteStore.listNotes(includeTrash: true)
        var notesByTitle = Dictionary(uniqueKeysWithValues: notes.map { ($0.title, $0) })

        for source in notes {
            let explicitLinks = try linkEngine.wikilinks(in: source.body).map { occurrence -> ExplicitLink in
                let target: Note
                if let existing = notesByTitle[occurrence.title] {
                    target = existing
                } else {
                    guard occurrence.createsPlaceholder else {
                        throw RuntimeError.noteNotFound(source.id)
                    }
                    let placeholder = try noteStore.createNote(
                        title: occurrence.title,
                        body: "",
                        creationProvenance: .placeholderCreated
                    )
                    notesByTitle[placeholder.title] = placeholder
                    target = placeholder
                }

                return ExplicitLink(
                    sourceNoteID: source.id,
                    targetNoteID: target.id,
                    snippet: occurrence.snippet
                )
            }
            try graphStore.replaceExplicitLinks(from: source.id, with: explicitLinks)
        }
    }
}
