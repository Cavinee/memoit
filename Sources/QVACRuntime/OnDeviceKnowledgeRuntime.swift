import Foundation

public final class OnDeviceKnowledgeRuntime {
    private let noteStore: NoteStore
    private let graphStore: any GraphStore
    private let linkEngine: MarkdownLinkEngine
    private let userSearchIndex: UserSearchIndex
    private let noteEmbeddingProvider: (any NoteEmbeddingProvider)?
    private let noteEmbeddingStore: (any NoteEmbeddingStore)?
    private let noteEmbeddingIndex = NoteEmbeddingIndex()
    private static let embeddingSearchTopK = 5
    private static let embeddingSearchThreshold: Float = 0.25
    // "Find Related Notes" surfaces a few more candidates at a slightly looser bar than
    // answer-grounding retrieval, since the user is browsing rather than feeding context.
    private static let relatedNotesTopK = 8
    private static let relatedNotesThreshold: Float = 0.20
    private let modelInventory: ModelInventoryStore
    private let aiRuntimeAdapter: any AIRuntimeAdapter
    private let aiSessionHistoryStore: AISessionHistoryStore
    private let savedAIResponseStore: SavedAIResponseStore
    private let aiOperationStore: AIOperationStore
    private let clock: () -> Date
    private var aiEditingPermissionsBySessionID: [AISessionID: AIEditingPermission] = [:]
    private var aiProgressState: AIProgressState = .idle

    init(noteStore: NoteStore, graphStore: any GraphStore, linkEngine: MarkdownLinkEngine, userSearchIndex: UserSearchIndex, noteEmbeddingProvider: (any NoteEmbeddingProvider)? = nil, noteEmbeddingStore: (any NoteEmbeddingStore)? = nil, modelInventory: ModelInventoryStore, aiRuntimeAdapter: any AIRuntimeAdapter, aiSessionHistoryStore: AISessionHistoryStore, savedAIResponseStore: SavedAIResponseStore, aiOperationStore: AIOperationStore, clock: @escaping () -> Date = Date.init) {
        self.noteStore = noteStore
        self.graphStore = graphStore
        self.linkEngine = linkEngine
        self.userSearchIndex = userSearchIndex
        self.noteEmbeddingProvider = noteEmbeddingProvider
        self.noteEmbeddingStore = noteEmbeddingStore
        self.modelInventory = modelInventory
        self.aiRuntimeAdapter = aiRuntimeAdapter
        self.aiSessionHistoryStore = aiSessionHistoryStore
        self.savedAIResponseStore = savedAIResponseStore
        self.aiOperationStore = aiOperationStore
        self.clock = clock
    }

    public func execute(_ command: RuntimeCommand, source: RuntimeCommandSource = .user) throws -> RuntimeCommandResult {
        if source == .ai && command.isForbiddenForAI {
            throw RuntimeError.runtimeCommandNotAllowedForAI
        }

        switch command {
        case .createNote(let command):
            if shouldDiscardEmptyUserCreatedNote(command) {
                return .discardedEmptyNote
            }
            let note = try noteStore.createNote(
                noteID: command.noteID,
                title: command.title,
                body: command.body,
                creationProvenance: command.creationProvenance,
                importProvenance: nil
            )
            try reconcileExplicitLinks(for: note)
            userSearchIndex.markDirty()
            return .createdNote(note)
        case .updateNoteBody(let command):
            let note = try noteStore.updateNoteBody(
                noteID: command.noteID,
                body: command.body
            )
            try reconcileExplicitLinks(for: note)
            userSearchIndex.markDirty()
            return .updatedNote(note)
        case .renameNote(let command):
            let note = try noteStore.renameNote(
                noteID: command.noteID,
                title: command.title
            )
            try updateIncomingWikilinkSources(targetNoteID: note.id, includeTrashedSources: true, includeSelfSource: true) { body, explicitLinks in
                rewriteWikilinkTokens(
                    in: body,
                    explicitLinks: explicitLinks,
                    targetNoteID: note.id
                ) { _ in "[[\(note.title)]]" }
            }
            userSearchIndex.markDirty()
            return .renamedNote(note)
        case .moveNoteToTrash(let command):
            let note = try noteStore.moveNoteToTrash(noteID: command.noteID)
            userSearchIndex.markDirty()
            return .movedNoteToTrash(note, TrashUndoOpportunity(noteID: note.id))
        case .setPinnedNote(let command):
            let note = try noteStore.setNotePinned(noteID: command.noteID, isPinned: command.isPinned)
            return .updatedNote(note)
        case .undoTrash(let command):
            let note = try noteStore.restoreNoteFromTrash(noteID: command.opportunity.noteID)
            userSearchIndex.markDirty()
            return .restoredNote(note)
        case .restoreNoteFromTrash(let command):
            let note = try noteStore.restoreNoteFromTrash(noteID: command.noteID)
            userSearchIndex.markDirty()
            return .restoredNote(note)
        case .permanentlyDeleteNote(let command):
            guard command.deletionConfirmation?.noteID == command.noteID else {
                throw RuntimeError.deletionConfirmationRequired(command.noteID)
            }
            guard let target = try noteStore.note(withID: command.noteID) else {
                throw RuntimeError.noteNotFound(command.noteID)
            }
            guard target.isTrashed else {
                throw RuntimeError.noteNotInTrash(command.noteID)
            }
            try updateIncomingWikilinkSources(targetNoteID: command.noteID, includeTrashedSources: true, includeSelfSource: false) { body, explicitLinks in
                removeWikilinkTokens(
                    in: body,
                    explicitLinks: explicitLinks,
                    targetNoteID: command.noteID
                )
            }
            try noteStore.permanentlyDeleteNote(noteID: command.noteID)
            try graphStore.removeExplicitLinks(involving: command.noteID)
            userSearchIndex.markDirty()
            return .permanentlyDeletedNote(command.noteID)
        case .runIndexingJobs(let command):
            let notes = try noteStore.listNotes()
            // Lexical refresh is cheap and main-thread-safe; the embedding rebuild can
            // block on a worklet. Scoping lets the app run lexical inline (freshness)
            // and embedding off the main thread without deadlocking.
            if command.scope != .embeddingOnly {
                userSearchIndex.rebuild(from: notes)
            }
            if command.scope != .lexicalOnly, let noteEmbeddingProvider {
                try noteEmbeddingIndex.rebuild(
                    from: notes,
                    provider: noteEmbeddingProvider,
                    store: noteEmbeddingStore,
                    modelID: noteEmbeddingProvider.modelID
                )
            }
            return .ranIndexingJobs
        case .importMarkdownFile(let command):
            return .importedMarkdown(try importMarkdown(files: [command.file]))
        case .importMarkdownFolder(let command):
            return .importedMarkdown(try importMarkdown(files: command.files))
        case .importExportBundle(let command):
            return .importedMarkdown(try importMarkdown(files: command.bundle.files, manifest: command.bundle.manifest))
        case .runRelationshipScan(let command):
            guard let note = try noteStore.note(withID: command.noteID) else {
                throw RuntimeError.noteNotFound(command.noteID)
            }
            guard !note.isTrashed else {
                throw RuntimeError.relationshipScanRequiresActiveNote(command.noteID)
            }
            guard !note.isPlaceholder else {
                throw RuntimeError.relationshipScanRequiresNonPlaceholderNote(command.noteID)
            }
            _ = try requireAvailableLocalModelProfile()
            return .suggestedRelationships(try aiRuntimeAdapter.suggestedRelationships(
                for: note,
                in: try noteStore.listNotes()
            ))
        case .createAcceptedRelationship(let command):
            guard try noteStore.note(withID: command.sourceNoteID) != nil else {
                throw RuntimeError.noteNotFound(command.sourceNoteID)
            }
            guard try noteStore.note(withID: command.targetNoteID) != nil else {
                throw RuntimeError.noteNotFound(command.targetNoteID)
            }
            return .createdAcceptedRelationship(try graphStore.createAcceptedRelationship(
                sourceNoteID: command.sourceNoteID,
                targetNoteID: command.targetNoteID
            ))
        case .promoteSuggestedRelationship(let command):
            let suggestion = command.suggestedRelationship
            guard try noteStore.note(withID: suggestion.sourceNoteID) != nil else {
                throw RuntimeError.noteNotFound(suggestion.sourceNoteID)
            }
            guard try noteStore.note(withID: suggestion.targetNoteID) != nil else {
                throw RuntimeError.noteNotFound(suggestion.targetNoteID)
            }
            return .createdAcceptedRelationship(try graphStore.createAcceptedRelationship(
                sourceNoteID: suggestion.sourceNoteID,
                targetNoteID: suggestion.targetNoteID
            ))
        case .recordLocalModelProfile(let command):
            return .recordedLocalModelProfile(modelInventory.record(command.profile))
        case .setDefaultLocalModelProfile(let command):
            return .updatedModelInventory(try modelInventory.setDefault(profileID: command.profileID))
        case .clearDefaultLocalModelProfile:
            return .updatedModelInventory(modelInventory.clearDefault())
        case .removeLocalModelProfile(let command):
            return .updatedModelInventory(try modelInventory.remove(profileID: command.profileID))
        case .refreshModelAvailabilityFromAdapter:
            let availability = try aiRuntimeAdapter.modelAvailability()
            let inventory = availability.isAIReady
                ? availability.inventory
                : ModelInventory(downloadedProfiles: [], defaultProfileID: nil)
            return .updatedModelInventory(modelInventory.replaceAdapterSourcedInventory(inventory))
        case .deleteAISessionHistoryEntry(let command):
            return .deletedAISessionHistoryEntry(try aiSessionHistoryStore.delete(entryID: command.entryID))
        case .saveAIResponse(let command):
            switch command.destination {
            case .newNote(let title):
                let note = try noteStore.createNote(
                    title: title,
                    body: command.response,
                    creationProvenance: .aiCreated
                )
                let createdPlaceholderNoteIDs = try reconcileExplicitLinks(for: note)
                userSearchIndex.markDirty()
                let profileID = modelInventory.chosenProfile()?.id
                let operation = aiOperationStore.recordCreatedNote(
                    noteID: note.id,
                    localModelProfileID: profileID,
                    newNote: profileID == nil ? nil : note,
                    createdPlaceholderNoteIDs: createdPlaceholderNoteIDs
                )
                return .savedAIResponse(savedAIResponseStore.record(
                    response: command.response,
                    destination: .note(note),
                    aiOperation: operation
                ))
            case .draftChange(let noteID):
                guard try noteStore.note(withID: noteID) != nil else {
                    throw RuntimeError.noteNotFound(noteID)
                }
                let draftChange = savedAIResponseStore.createDraftChange(
                    noteID: noteID,
                    body: command.response
                )
                return .savedAIResponse(savedAIResponseStore.record(
                    response: command.response,
                    destination: .draftChange(draftChange),
                    aiOperation: nil
                ))
            }
        case .setAIEditingPermission(let command):
            aiEditingPermissionsBySessionID[command.permission.sessionID] = command.permission
            return .setAIEditingPermission(command.permission)
        case .runAIWriteWorkflow(let command):
            guard let destinations = command.destinations, !destinations.isEmpty else {
                throw RuntimeError.aiWriteDestinationRequired
            }

            let profile = try requireAvailableLocalModelProfile()
            let generated = try aiRuntimeAdapter.generatedNoteBodies(
                prompt: command.prompt,
                destinationCount: destinations.count
            )

            switch generated {
            case .canceled:
                return .aiWriteWorkflow(.canceled)
            case .completed(let bodies):
                guard bodies.count == destinations.count else {
                    throw RuntimeError.aiGeneratedWriteCountMismatch
                }
                let mode = aiEditingPermissionsBySessionID[command.sessionID]?.mode ?? .draftChange
                switch mode {
                case .draftChange:
                    guard case .existingNote(let noteID) = destinations[0] else {
                        throw RuntimeError.aiWriteDestinationRequired
                    }
                    guard try noteStore.note(withID: noteID) != nil else {
                        throw RuntimeError.noteNotFound(noteID)
                    }
                    let draftChange = savedAIResponseStore.createDraftChange(
                        noteID: noteID,
                        body: bodies[0],
                        localModelProfileID: profile.id
                    )
                    return .aiWriteWorkflow(.draftChange(draftChange))
                case .directEdit:
                    var previousNotesByID: [NoteID: Note] = [:]
                    var plannedChanges: [AIChange] = []
                    for destination in destinations {
                        if case .existingNote(let noteID) = destination {
                            guard let previousNote = try noteStore.note(withID: noteID) else {
                                throw RuntimeError.noteNotFound(noteID)
                            }
                            previousNotesByID[noteID] = previousNote
                        }
                    }
                    for (destination, body) in zip(destinations, bodies) {
                        if case .existingNote(let noteID) = destination {
                            let previousNote = previousNotesByID[noteID]!
                            plannedChanges.append(AIChange(
                                noteID: noteID,
                                previousNote: previousNote,
                                newNote: Note(
                                    id: previousNote.id,
                                    title: previousNote.title,
                                    body: body,
                                    creationProvenance: previousNote.creationProvenance,
                                    isPlaceholder: previousNote.isPlaceholder && body.isEmpty,
                                    isTrashed: previousNote.isTrashed
                                )
                            ))
                        }
                    }
                    let operation = try aiOperationStore.record(
                        localModelProfileID: profile.id,
                        changes: plannedChanges
                    )
                    var changes: [AIChange] = []
                    var createdPlaceholderNoteIDs: [NoteID] = []
                    for (destination, body) in zip(destinations, bodies) {
                        switch destination {
                        case .existingNote(let noteID):
                            let previousNote = previousNotesByID[noteID]!
                            let updatedNote = try noteStore.updateNoteBody(noteID: noteID, body: body)
                            createdPlaceholderNoteIDs.append(contentsOf: try reconcileExplicitLinks(for: updatedNote))
                            changes.append(AIChange(noteID: noteID, previousNote: previousNote, newNote: updatedNote))
                        case .newNote(let title):
                            let note = try noteStore.createNote(
                                title: title,
                                body: body,
                                creationProvenance: .aiCreated
                            )
                            createdPlaceholderNoteIDs.append(contentsOf: try reconcileExplicitLinks(for: note))
                            changes.append(AIChange(noteID: note.id, previousNote: nil, newNote: note))
                        }
                    }
                    userSearchIndex.markDirty()
                    let finalizedOperation = try aiOperationStore.replace(
                        operationID: operation.id,
                        changes: changes,
                        createdPlaceholderNoteIDs: createdPlaceholderNoteIDs
                    )
                    return .aiWriteWorkflow(.directEdit(finalizedOperation))
                }
            }
        case .acceptDraftChange(let command):
            let draftChange = try savedAIResponseStore.draftChange(withID: command.draftChangeID)
            guard let previousNote = try noteStore.note(withID: draftChange.noteID) else {
                throw RuntimeError.noteNotFound(draftChange.noteID)
            }
            let plannedNote = Note(
                id: previousNote.id,
                title: previousNote.title,
                body: draftChange.body,
                creationProvenance: previousNote.creationProvenance,
                isPlaceholder: previousNote.isPlaceholder && draftChange.body.isEmpty,
                isTrashed: previousNote.isTrashed
            )
            let operation = try aiOperationStore.record(
                localModelProfileID: draftChange.localModelProfileID,
                changes: [
                    AIChange(noteID: draftChange.noteID, previousNote: previousNote, newNote: plannedNote)
                ]
            )
            let updatedNote = try noteStore.updateNoteBody(
                noteID: draftChange.noteID,
                body: draftChange.body
            )
            let createdPlaceholderNoteIDs = try reconcileExplicitLinks(for: updatedNote)
            userSearchIndex.markDirty()
            savedAIResponseStore.deleteDraftChange(draftChangeID: command.draftChangeID)
            let finalizedOperation = try aiOperationStore.replace(
                operationID: operation.id,
                changes: [
                    AIChange(noteID: draftChange.noteID, previousNote: previousNote, newNote: updatedNote)
                ],
                createdPlaceholderNoteIDs: createdPlaceholderNoteIDs
            )
            return .acceptedDraftChange(finalizedOperation)
        case .cancelDraftChange(let command):
            _ = try savedAIResponseStore.draftChange(withID: command.draftChangeID)
            savedAIResponseStore.deleteDraftChange(draftChangeID: command.draftChangeID)
            return .canceledDraftChange(command.draftChangeID)
        case .beginIncompleteAIOperation(let command):
            return .beganIncompleteAIOperation(aiOperationStore.beginIncomplete(
                localModelProfileID: command.localModelProfileID,
                changes: command.changes
            ))
        case .simulateCrashRestart:
            aiOperationStore.discardIncompleteOperations()
            return .simulatedCrashRestart
        case .simulateIncompleteAIWriteWorkflow(let command):
            guard let destinations = command.workflow.destinations, !destinations.isEmpty else {
                throw RuntimeError.aiWriteDestinationRequired
            }
            let profile = try requireAvailableLocalModelProfile()
            let generated = try aiRuntimeAdapter.generatedNoteBodies(
                prompt: command.workflow.prompt,
                destinationCount: destinations.count
            )
            switch generated {
            case .canceled:
                return .simulatedCrashRestart
            case .completed(let bodies):
                guard bodies.count == destinations.count else {
                    throw RuntimeError.aiGeneratedWriteCountMismatch
                }
                var changes: [AIChange] = []
                for (destination, body) in zip(destinations, bodies) {
                    if case .existingNote(let noteID) = destination {
                        guard let previousNote = try noteStore.note(withID: noteID) else {
                            throw RuntimeError.noteNotFound(noteID)
                        }
                        changes.append(AIChange(
                            noteID: noteID,
                            previousNote: previousNote,
                            newNote: Note(
                                id: previousNote.id,
                                title: previousNote.title,
                                body: body,
                                creationProvenance: previousNote.creationProvenance,
                                isPlaceholder: previousNote.isPlaceholder && body.isEmpty,
                                isTrashed: previousNote.isTrashed
                            )
                        ))
                    }
                }
                _ = aiOperationStore.beginIncomplete(localModelProfileID: profile.id, changes: changes)
                aiOperationStore.discardIncompleteOperations()
                return .simulatedCrashRestart
            }
        case .simulateIncompleteDraftAcceptance(let command):
            let draftChange = try savedAIResponseStore.draftChange(withID: command.draftChangeID)
            guard let previousNote = try noteStore.note(withID: draftChange.noteID) else {
                throw RuntimeError.noteNotFound(draftChange.noteID)
            }
            _ = aiOperationStore.beginIncomplete(
                localModelProfileID: draftChange.localModelProfileID,
                changes: [
                    AIChange(
                        noteID: draftChange.noteID,
                        previousNote: previousNote,
                        newNote: Note(
                            id: previousNote.id,
                            title: previousNote.title,
                            body: draftChange.body,
                            creationProvenance: previousNote.creationProvenance,
                            isPlaceholder: previousNote.isPlaceholder && draftChange.body.isEmpty,
                            isTrashed: previousNote.isTrashed
                        )
                    )
                ]
            )
            aiOperationStore.discardIncompleteOperations()
            return .simulatedCrashRestart
        case .failNextAIOperationCommit:
            aiOperationStore.failNextCommit()
            return .configuredAIOperationCommitFailure
        case .reverseAIOperation(let command):
            let operation = try aiOperationStore.operation(withID: command.operationID)
            if !operation.isReversed {
                for change in operation.changes.reversed() {
                    if let previousNote = change.previousNote {
                        _ = try noteStore.replaceNote(previousNote)
                        try reconcileExplicitLinks(for: previousNote)
                    } else {
                        _ = try noteStore.moveNoteToTrash(noteID: change.noteID)
                        try graphStore.replaceExplicitLinks(from: change.noteID, with: [])
                    }
                }
                for placeholderNoteID in operation.createdPlaceholderNoteIDs {
                    guard let placeholder = try noteStore.note(withID: placeholderNoteID), placeholder.isPlaceholder, placeholder.body.isEmpty, !placeholder.isTrashed else {
                        continue
                    }
                    guard try graphStore.backlinks(to: placeholderNoteID, sourceNote: { [noteStore] sourceNoteID in
                        try noteStore.note(withID: sourceNoteID)
                    }).isEmpty else {
                        continue
                    }
                    _ = try noteStore.moveNoteToTrash(noteID: placeholderNoteID)
                    try graphStore.removeExplicitLinks(involving: placeholderNoteID)
                }
                userSearchIndex.markDirty()
            }
            return .reversedAIOperation(try aiOperationStore.markReversed(operationID: command.operationID))
        }
    }

    public func query(_ query: RuntimeQuery) throws -> RuntimeQueryResult {
        switch query {
        case .note(let noteID):
            return .note(try noteStore.note(withID: noteID))
        case .notes:
            return .notes(try noteStore.listNotes())
        case .homeNotes:
            return .homeNotes(try homeNoteList())
        case .trashedNotes:
            return .trashedNotes(try noteStore.listNotes(includeTrash: true).filter(\.isTrashed))
        case .explicitLinks(let sourceNoteID):
            return .explicitLinks(try graphStore.explicitLinks(from: sourceNoteID))
        case .backlinks(let targetNoteID):
            return .backlinks(try graphStore.backlinks(to: targetNoteID) { [noteStore] sourceNoteID in
                try noteStore.note(withID: sourceNoteID)
            })
        case .trustedGraph:
            return .trustedGraph(try graphStore.trustedGraph(notes: try noteStore.listNotes()))
        case .userSearch(let query):
            let activeNotesByID = Dictionary(uniqueKeysWithValues: try noteStore.listNotes().map { ($0.id, $0) })
            return .userSearchResults(userSearchIndex.search(query).compactMap { activeNotesByID[$0] })
        case .relatedNotes(let noteID):
            return .relatedNotes(try relatedNotes(to: noteID))
        case .indexFreshness(let index):
            switch index {
            case .userSearch:
                return .indexFreshness(userSearchIndex.freshness)
            }
        case .aiReadyDevice:
            return .aiReadyDevice(modelInventory.chosenProfile() != nil)
        case .aiUnavailableState:
            return .aiUnavailableState(modelInventory.chosenProfile() == nil ? .noUsableLocalModelProfile : nil)
        case .modelInventory:
            return .modelInventory(modelInventory.inventory())
        case .chosenLocalModelProfile:
            return .chosenLocalModelProfile(modelInventory.chosenProfile())
        case .aiProgressState:
            return .aiProgressState(aiProgressState)
        case .aiSessionHistory:
            return .aiSessionHistory(aiSessionHistoryStore.list())
        case .aiOperations:
            return .aiOperations(aiOperationStore.list())
        case .markdownExport(let options):
            return .markdownExport(try exportMarkdown(options: options))
        case .exportBundle(let options):
            let export = try exportMarkdown(options: options)
            return .exportBundle(MarkdownExportBundle(
                files: export.files,
                manifest: export.manifest,
                aiSessionHistory: options.includeAISessionHistory ? aiSessionHistoryStore.list() : []
            ))
        case .singleNoteShare(let noteID):
            return .singleNoteShare(try shareNote(noteID: noteID))
        case .diagnosticsExport:
            return .diagnosticsExport(try diagnosticsExport())
        }
    }

    /// Notes semantically related to `noteID`, ranked most-similar first. Uses the
    /// note's already-computed embedding via cosine similarity — it never re-embeds and
    /// never touches the answer/generation worklet. Before the embedding index is built
    /// (fresh install), it falls back to a lexical search on the note's title so the
    /// feature still returns something. Excludes the note itself and any placeholders.
    private func relatedNotes(to noteID: NoteID) throws -> [Note] {
        let activeNotesByID = Dictionary(uniqueKeysWithValues: try noteStore.listNotes().map { ($0.id, $0) })

        let relatedIDs: [NoteID]
        if noteEmbeddingIndex.isReady {
            relatedIDs = noteEmbeddingIndex.relatedNoteIDs(
                to: noteID,
                topK: Self.relatedNotesTopK,
                threshold: Self.relatedNotesThreshold
            )
        } else if let note = activeNotesByID[noteID] {
            // Embedding index not built yet (fresh install). Approximate "related" with a
            // lexical OR over the note's title tokens — UserSearchIndex.search is AND-only
            // per query, so a single full-title query would miss partial-overlap notes.
            let titleTokens = note.title
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .filter { $0.count > 1 }
            var seen: Set<NoteID> = [noteID]
            var ordered: [NoteID] = []
            for token in titleTokens {
                for id in userSearchIndex.search(String(token)) where !seen.contains(id) {
                    seen.insert(id)
                    ordered.append(id)
                }
            }
            relatedIDs = Array(ordered.prefix(Self.relatedNotesTopK))
        } else {
            relatedIDs = []
        }

        return relatedIDs.compactMap { activeNotesByID[$0] }.filter { !$0.isPlaceholder }
    }

    public func answer(_ request: AnswerRequest) throws -> AnswerResult {
        _ = try requireAvailableLocalModelProfile()
        if request.mode == .noteGrounded, userSearchIndex.freshness != .fresh {
            throw RuntimeError.indexNotFresh(.userSearch)
        }

        let context = request.mode == .noteGrounded ? try retrievedNotes(for: request.prompt) : []
        if request.mode == .noteGrounded, context.isEmpty {
            throw RuntimeError.noRetrievedContext(.noteGrounded)
        }
        let citations = context.map { SourceCitation(noteID: $0.id, noteFragmentID: "note-body") }
        let answer = try aiRuntimeAdapter.answer(
            prompt: request.prompt,
            mode: request.mode,
            context: context
        )
        _ = aiSessionHistoryStore.record(
            prompt: request.prompt,
            response: answer,
            mode: request.mode,
            createdAt: clock(),
            citations: citations
        )

        return AnswerResult(
            answer: answer,
            mode: request.mode,
            modeLabel: request.mode.label,
            isConstrainedToRetrievedNotes: request.mode.isConstrainedToRetrievedNotes,
            citations: citations
        )
    }

    public func summarize(_ request: SummaryRequest) throws -> SummaryResult {
        let profile = try requireAvailableLocalModelProfile()
        if case .newNote = request.destination, aiEditingPermissionsBySessionID[request.sessionID]?.mode != .directEdit {
            throw RuntimeError.aiWriteDestinationRequired
        }
        let sourceNotes = try summarySourceNotes(for: request.source)
        defer { aiProgressState = .idle }
        let summary = try aiRuntimeAdapter.summary(for: sourceNotes) { [self] progress in
            aiProgressState = progress
        }
        let citations = sourceNotes.map { SourceCitation(noteID: $0.id, noteFragmentID: "note-body") }

        switch request.destination {
        case .responseOnly:
            return SummaryResult(summary: summary, citations: citations, output: .responseOnly)
        case .draftChange(let noteID):
            guard try noteStore.note(withID: noteID) != nil else {
                throw RuntimeError.noteNotFound(noteID)
            }
            let draftChange = savedAIResponseStore.createDraftChange(
                noteID: noteID,
                body: summary,
                localModelProfileID: profile.id
            )
            return SummaryResult(summary: summary, citations: citations, output: .draftChange(draftChange))
        case .newNote(let title):
            let operation = try aiOperationStore.record(localModelProfileID: profile.id, changes: [])
            let note = try noteStore.createNote(
                title: title,
                body: summary,
                creationProvenance: .aiCreated
            )
            let createdPlaceholderNoteIDs = try reconcileExplicitLinks(for: note)
            userSearchIndex.markDirty()
            let finalizedOperation = try aiOperationStore.replace(
                operationID: operation.id,
                changes: [
                    AIChange(noteID: note.id, previousNote: nil, newNote: note)
                ],
                createdPlaceholderNoteIDs: createdPlaceholderNoteIDs
            )
            return SummaryResult(summary: summary, citations: citations, output: .newNote(note, finalizedOperation))
        }
    }

    private func shouldDiscardEmptyUserCreatedNote(_ command: CreateNoteCommand) -> Bool {
        command.creationProvenance == .userCreated &&
        UserCreatedNoteDraftDiscardPolicy.shouldDiscard(title: command.title, body: command.body)
    }

    private func homeNoteList() throws -> HomeNoteList {
        let notes = try noteStore.listNotes()
        let pinnedNotes = orderedForHome(notes.filter(\.isPinned))
        let regularNotes = orderedForHome(notes.filter { !$0.isPinned })
        return HomeNoteList(
            pinnedNotes: pinnedNotes,
            groups: noteListGroups(for: regularNotes, now: clock())
        )
    }

    private func orderedForHome(_ notes: [Note]) -> [Note] {
        notes.enumerated().sorted { lhs, rhs in
            if lhs.element.lastEditedAt != rhs.element.lastEditedAt {
                return lhs.element.lastEditedAt > rhs.element.lastEditedAt
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private func noteListGroups(for notes: [Note], now: Date) -> [NoteListGroup] {
        var groups: [NoteListGroup] = []
        for note in notes {
            let title = noteListGroupTitle(for: note.lastEditedAt, now: now)
            if let index = groups.firstIndex(where: { $0.title == title }) {
                var groupedNotes = groups[index].notes
                groupedNotes.append(note)
                groups[index] = NoteListGroup(title: title, notes: groupedNotes)
            } else {
                groups.append(NoteListGroup(title: title, notes: [note]))
            }
        }
        return groups
    }

    private func noteListGroupTitle(for lastEditedAt: Date, now: Date) -> String {
        let age = now.timeIntervalSince(lastEditedAt)
        if age < 86_400 {
            return "TODAY"
        }
        if age < 172_800 {
            return "YESTERDAY"
        }
        return "A WEEK AGO"
    }

    private func summarySourceNotes(for source: SummarySource) throws -> [Note] {
        switch source {
        case .selectedNoteIDs(let noteIDs):
            return try noteIDs.map { noteID in
                guard let note = try noteStore.note(withID: noteID) else {
                    throw RuntimeError.noteNotFound(noteID)
                }

                return note
            }
        case .retrievedNotes(let prompt):
            if userSearchIndex.freshness != .fresh {
                throw RuntimeError.indexNotFresh(.userSearch)
            }
            let notes = try retrievedNotes(for: prompt)
            if notes.isEmpty {
                throw RuntimeError.noRetrievedContext(.noteGrounded)
            }

            return notes
        }
    }

    public func requireAvailableLocalModelProfile() throws -> LocalModelProfile {
        guard let profile = modelInventory.chosenProfile() else {
            throw RuntimeError.aiUnavailable(.noUsableLocalModelProfile)
        }

        return profile
    }

    @discardableResult
    private func reconcileExplicitLinks(for note: Note, includeMarkdownLinks: Bool = false, sourcePath: String? = nil, importedTargetNoteIDsByTitle: [String: NoteID] = [:], importedTargetNoteIDsByPath: [String: NoteID] = [:]) throws -> [NoteID] {
        var createdPlaceholderNoteIDs: [NoteID] = []
        let occurrences = includeMarkdownLinks ? linkEngine.importedLinks(in: note.body) : linkEngine.wikilinks(in: note.body)
        let explicitLinks = try occurrences.compactMap { occurrence -> ExplicitLink? in
            let targetNote: Note
            if let sourcePath,
               let targetPath = occurrence.markdownTargetPath,
               let importedTargetNoteID = importedTargetNoteIDsByPath[importedPath(for: targetPath, from: sourcePath)],
               let importedTarget = try noteStore.note(withID: importedTargetNoteID) {
                targetNote = importedTarget
            } else if let importedTargetNoteID = importedTargetNoteIDsByTitle[occurrence.title],
               let importedTarget = try noteStore.note(withID: importedTargetNoteID) {
                targetNote = importedTarget
            } else if let existing = try noteStore.note(titled: occurrence.title) {
                targetNote = existing
            } else {
                guard occurrence.createsPlaceholder else {
                    return nil
                }
                targetNote = try noteStore.createNote(
                    title: occurrence.title,
                    body: "",
                    creationProvenance: .placeholderCreated
                )
                createdPlaceholderNoteIDs.append(targetNote.id)
            }

            return ExplicitLink(
                sourceNoteID: note.id,
                targetNoteID: targetNote.id,
                snippet: occurrence.snippet
            )
        }

        try graphStore.replaceExplicitLinks(from: note.id, with: explicitLinks)
        return createdPlaceholderNoteIDs
    }

    private func updateIncomingWikilinkSources(targetNoteID: NoteID, includeTrashedSources: Bool, includeSelfSource: Bool, rewriteBody: (String, [ExplicitLink]) -> String) throws {
        for sourceNoteID in try graphStore.sourceNoteIDsWithExplicitLinks(to: targetNoteID) where includeSelfSource || sourceNoteID != targetNoteID {
            guard let source = try noteStore.note(withID: sourceNoteID),
                  includeTrashedSources || !source.isTrashed else {
                continue
            }

            let explicitLinks = try graphStore.explicitLinks(from: source.id)
            let rewrittenBody = rewriteBody(source.body, explicitLinks)
            guard rewrittenBody != source.body else {
                continue
            }
            let preservedExplicitLinks = manifestOnlyExplicitLinks(in: source.body, explicitLinks: explicitLinks)

            let rewritten = Note(
                id: source.id,
                title: source.title,
                body: rewrittenBody,
                creationProvenance: source.creationProvenance,
                importProvenance: source.importProvenance,
                isPlaceholder: source.isPlaceholder,
                isTrashed: source.isTrashed,
                isPinned: source.isPinned,
                lastEditedAt: source.lastEditedAt
            )
            _ = try noteStore.replaceNote(rewritten)
            try reconcileExplicitLinksAfterMechanicalWikilinkRewrite(for: rewritten, preservingExplicitLinks: preservedExplicitLinks)
        }
    }

    private func reconcileExplicitLinksAfterMechanicalWikilinkRewrite(for note: Note, preservingExplicitLinks preservedExplicitLinks: [ExplicitLink]) throws {
        guard let sourcePath = note.importProvenance?.sourcePath else {
            try reconcileExplicitLinks(for: note)
            return
        }

        let importedTargets = try importedTargetNoteIDLookups()
        try reconcileExplicitLinks(
            for: note,
            includeMarkdownLinks: true,
            sourcePath: sourcePath,
            importedTargetNoteIDsByTitle: importedTargets.byTitle,
            importedTargetNoteIDsByPath: importedTargets.byPath
        )
        try appendPreservedExplicitLinks(preservedExplicitLinks, from: note.id)
    }

    private func appendPreservedExplicitLinks(_ preservedExplicitLinks: [ExplicitLink], from sourceNoteID: NoteID) throws {
        guard !preservedExplicitLinks.isEmpty else {
            return
        }

        var explicitLinks = try graphStore.explicitLinks(from: sourceNoteID)
        for explicitLink in preservedExplicitLinks where !explicitLinks.contains(explicitLink) {
            explicitLinks.append(explicitLink)
        }
        try graphStore.replaceExplicitLinks(from: sourceNoteID, with: explicitLinks)
    }

    private func importedTargetNoteIDLookups() throws -> (byTitle: [String: NoteID], byPath: [String: NoteID]) {
        var byTitle: [String: NoteID] = [:]
        var byPath: [String: NoteID] = [:]

        for note in try noteStore.listNotes(includeTrash: true) {
            guard let sourcePath = note.importProvenance?.sourcePath else {
                continue
            }

            byTitle[markdownTitle(from: sourcePath)] = note.id
            byPath[normalizedImportPath(sourcePath)] = note.id
        }

        return (byTitle, byPath)
    }

    private func rewriteWikilinkTokens(in body: String, explicitLinks: [ExplicitLink], targetNoteID: NoteID, replacement: (WikilinkOccurrence) -> String) -> String {
        let replacements = wikilinkExplicitLinkPairs(in: body, explicitLinks: explicitLinks).compactMap { occurrence, explicitLink -> (Range<String.Index>, String)? in
            guard explicitLink.targetNoteID == targetNoteID,
                  let tokenRange = wikilinkTokenRange(in: body, startingAt: occurrence.position) else {
                return nil
            }

            return (tokenRange, replacement(occurrence))
        }

        return applying(replacements: replacements, to: body)
    }

    private func removeWikilinkTokens(in body: String, explicitLinks: [ExplicitLink], targetNoteID: NoteID) -> String {
        let tokenRanges = wikilinkExplicitLinkPairs(in: body, explicitLinks: explicitLinks).compactMap { occurrence, explicitLink -> Range<String.Index>? in
            guard explicitLink.targetNoteID == targetNoteID,
                  let tokenRange = wikilinkTokenRange(in: body, startingAt: occurrence.position) else {
                return nil
            }

            return tokenRange
        }
        let replacements = coalescedAdjacentWikilinkRemovalRanges(tokenRanges, in: body).map { removalRange in
            (wikilinkRemovalRange(in: body, tokenRange: removalRange), "")
        }

        return applying(replacements: replacements, to: body)
    }

    private func wikilinkExplicitLinkPairs(in body: String, explicitLinks: [ExplicitLink]) -> [(occurrence: WikilinkOccurrence, explicitLink: ExplicitLink)] {
        importedOccurrenceExplicitLinkPairs(in: body, explicitLinks: explicitLinks).compactMap { occurrence, _, explicitLink in
            guard occurrence.markdownTargetPath == nil else {
                return nil
            }

            return (occurrence, explicitLink)
        }
    }

    private func manifestOnlyExplicitLinks(in body: String, explicitLinks: [ExplicitLink]) -> [ExplicitLink] {
        let bodyExplicitLinkIndexes = Set(importedOccurrenceExplicitLinkPairs(in: body, explicitLinks: explicitLinks).map(\.explicitLinkIndex))
        return explicitLinks.enumerated().compactMap { index, explicitLink in
            bodyExplicitLinkIndexes.contains(index) ? nil : explicitLink
        }
    }

    private func importedOccurrenceExplicitLinkPairs(in body: String, explicitLinks: [ExplicitLink]) -> [(occurrence: WikilinkOccurrence, explicitLinkIndex: Int, explicitLink: ExplicitLink)] {
        let importedOccurrences = linkEngine.importedLinks(in: body)
        var remainingExplicitLinkIndexes = Array(explicitLinks.indices)
        var pairs: [(occurrence: WikilinkOccurrence, explicitLinkIndex: Int, explicitLink: ExplicitLink)] = []

        for occurrence in importedOccurrences {
            guard let remainingIndex = remainingExplicitLinkIndexes.firstIndex(where: { explicitLinks[$0].snippet == occurrence.snippet }) else {
                continue
            }
            let explicitLinkIndex = remainingExplicitLinkIndexes.remove(at: remainingIndex)
            pairs.append((occurrence, explicitLinkIndex, explicitLinks[explicitLinkIndex]))
        }

        return pairs
    }

    private func coalescedAdjacentWikilinkRemovalRanges(_ tokenRanges: [Range<String.Index>], in body: String) -> [Range<String.Index>] {
        var coalesced: [Range<String.Index>] = []

        for tokenRange in tokenRanges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard let previous = coalesced.last else {
                coalesced.append(tokenRange)
                continue
            }

            if body[previous.upperBound..<tokenRange.lowerBound].allSatisfy(isHorizontalWhitespace) {
                coalesced[coalesced.index(before: coalesced.endIndex)] = previous.lowerBound..<tokenRange.upperBound
            } else {
                coalesced.append(tokenRange)
            }
        }

        return coalesced
    }

    private func applying(replacements: [(Range<String.Index>, String)], to body: String) -> String {
        var result = ""
        var cursor = body.startIndex

        for replacement in replacements.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            guard replacement.0.lowerBound >= cursor else {
                continue
            }
            result += body[cursor..<replacement.0.lowerBound]
            result += replacement.1
            cursor = replacement.0.upperBound
        }

        result += body[cursor..<body.endIndex]
        return result
    }

    private func wikilinkTokenRange(in body: String, startingAt opening: String.Index) -> Range<String.Index>? {
        guard opening < body.endIndex,
              body[opening...].hasPrefix("[["),
              let contentStart = body.index(opening, offsetBy: 2, limitedBy: body.endIndex),
              let closing = body.range(of: "]]", range: contentStart..<body.endIndex) else {
            return nil
        }

        return opening..<closing.upperBound
    }

    private func wikilinkRemovalRange(in body: String, tokenRange: Range<String.Index>) -> Range<String.Index> {
        let afterSpaces = horizontalWhitespaceEnd(in: body, startingAt: tokenRange.upperBound)

        if afterSpaces < body.endIndex, isClosingPunctuation(body[afterSpaces]) {
            return horizontalWhitespaceStart(in: body, endingAt: tokenRange.lowerBound)..<tokenRange.upperBound
        }

        if afterSpaces > tokenRange.upperBound {
            return tokenRange.lowerBound..<afterSpaces
        }

        if tokenRange.upperBound == body.endIndex {
            return horizontalWhitespaceStart(in: body, endingAt: tokenRange.lowerBound)..<tokenRange.upperBound
        }

        return tokenRange
    }

    private func horizontalWhitespaceStart(in body: String, endingAt end: String.Index) -> String.Index {
        var start = end
        while start > body.startIndex {
            let previous = body.index(before: start)
            guard isHorizontalWhitespace(body[previous]) else {
                break
            }
            start = previous
        }
        return start
    }

    private func horizontalWhitespaceEnd(in body: String, startingAt start: String.Index) -> String.Index {
        var end = start
        while end < body.endIndex, isHorizontalWhitespace(body[end]) {
            end = body.index(after: end)
        }
        return end
    }

    private func isHorizontalWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    private func isClosingPunctuation(_ character: Character) -> Bool {
        [".", ",", "!", "?", ";", ":"].contains(character)
    }

    private func importMarkdown(files: [MarkdownImportFile], manifest: MarkdownExportManifest = .init()) throws -> MarkdownImportResult {
        var importedNotes: [Note] = []
        var provenanceByNoteID: [NoteID: ImportProvenance] = [:]
        var importedNoteIDByManifestID: [NoteID: NoteID] = [:]
        var importedTargetNoteIDsByTitle: [String: NoteID] = [:]
        var importedTargetNoteIDsByPath: [String: NoteID] = [:]
        var importedSources: [(note: Note, path: String)] = []

        for file in files {
            let sourceTitle = markdownTitle(from: file.path)
            let provenance = manifest.importProvenanceByPath[file.path] ?? ImportProvenance(sourcePath: file.path)
            let manifestNoteID = manifest.noteIDsByPath[file.path]
            let note = try noteStore.createNote(
                noteID: manifestNoteID,
                title: sourceTitle,
                body: file.body,
                creationProvenance: .imported,
                importProvenance: provenance
            )
            importedNotes.append(note)
            importedSources.append((note, file.path))
            provenanceByNoteID[note.id] = provenance
            importedTargetNoteIDsByTitle[sourceTitle] = note.id
            importedTargetNoteIDsByPath[normalizedImportPath(file.path)] = note.id
            if let manifestNoteID {
                importedNoteIDByManifestID[manifestNoteID] = note.id
            }
        }

        for source in importedSources {
            try reconcileExplicitLinks(
                for: source.note,
                includeMarkdownLinks: true,
                sourcePath: source.path,
                importedTargetNoteIDsByTitle: importedTargetNoteIDsByTitle,
                importedTargetNoteIDsByPath: importedTargetNoteIDsByPath
            )
        }
        for link in manifest.explicitLinks {
            guard let sourceNoteID = importedNoteIDByManifestID[link.sourceNoteID],
                  let targetNoteID = importedNoteIDByManifestID[link.targetNoteID] else {
                continue
            }
            let explicitLink = ExplicitLink(sourceNoteID: sourceNoteID, targetNoteID: targetNoteID, snippet: link.snippet)
            var explicitLinks = try graphStore.explicitLinks(from: sourceNoteID)
            if !explicitLinks.contains(explicitLink) {
                explicitLinks.append(explicitLink)
            }
            try graphStore.replaceExplicitLinks(from: sourceNoteID, with: explicitLinks)
        }
        for relationship in manifest.acceptedRelationships {
            guard let sourceNoteID = importedNoteIDByManifestID[relationship.sourceNoteID],
                  let targetNoteID = importedNoteIDByManifestID[relationship.targetNoteID] else {
                continue
            }
            _ = try graphStore.createAcceptedRelationship(sourceNoteID: sourceNoteID, targetNoteID: targetNoteID)
        }
        userSearchIndex.markDirty()
        return MarkdownImportResult(notes: importedNotes, provenance: provenanceByNoteID)
    }

    private func exportMarkdown(options: MarkdownExportOptions) throws -> MarkdownExportResult {
        var usedFilenames = Set<String>()
        var nextSuffixByBase: [String: Int] = [:]
        var files: [MarkdownExportFile] = []
        var noteIDsByPath: [String: NoteID] = [:]
        var importProvenanceByPath: [String: ImportProvenance] = [:]
        let notes = try noteStore.listNotes(includeTrash: options.includeTrash)
        let exportedNoteIDs = Set(notes.map(\.id))

        for note in notes {
            let base = filesystemSafeMarkdownBase(from: note.title)
            let filename = uniqueMarkdownFilename(base: base, usedFilenames: &usedFilenames, nextSuffixByBase: &nextSuffixByBase)
            files.append(MarkdownExportFile(path: filename, body: try renderedExportBody(for: note)))
            noteIDsByPath[filename] = note.id
            if let importProvenance = note.importProvenance {
                importProvenanceByPath[filename] = importProvenance
            }
        }
        let explicitLinks = try notes.flatMap { note in
            try graphStore.explicitLinks(from: note.id).filter { exportedNoteIDs.contains($0.targetNoteID) }
        }
        let acceptedRelationships = try graphStore.listAcceptedRelationships().filter {
            exportedNoteIDs.contains($0.sourceNoteID) && exportedNoteIDs.contains($0.targetNoteID)
        }

        return MarkdownExportResult(
            files: files,
            manifest: MarkdownExportManifest(
                noteIDsByPath: noteIDsByPath,
                explicitLinks: explicitLinks,
                acceptedRelationships: acceptedRelationships,
                importProvenanceByPath: importProvenanceByPath,
                editProvenance: options.includeEditProvenance ? editProvenance(for: exportedNoteIDs) : []
            )
        )
    }

    private func renderedExportBody(for note: Note) throws -> String {
        let links = try graphStore.explicitLinks(from: note.id).filter { $0.snippet.contains("[[") }
        guard !links.isEmpty else {
            return note.body
        }

        var result = ""
        var searchStart = note.body.startIndex
        var linkIndex = 0

        while let opening = note.body.range(of: "[[", range: searchStart..<note.body.endIndex) {
            guard let closing = note.body.range(of: "]]", range: opening.upperBound..<note.body.endIndex) else {
                break
            }
            if opening.lowerBound > note.body.startIndex, note.body[note.body.index(before: opening.lowerBound)] == "!" {
                result += String(note.body[searchStart..<closing.upperBound])
                searchStart = closing.upperBound
                continue
            }

            result += String(note.body[searchStart..<opening.lowerBound])
            if linkIndex < links.count, let target = try noteStore.note(withID: links[linkIndex].targetNoteID) {
                result += "[[\(target.title)]]"
                linkIndex += 1
            } else {
                result += String(note.body[opening.lowerBound..<closing.upperBound])
            }
            searchStart = closing.upperBound
        }

        result += String(note.body[searchStart..<note.body.endIndex])
        return result
    }

    private func editProvenance(for exportedNoteIDs: Set<NoteID>) -> [AIOperation] {
        aiOperationStore.list().filter { operation in
            operation.changes.contains { exportedNoteIDs.contains($0.noteID) } ||
            operation.createdPlaceholderNoteIDs.contains { exportedNoteIDs.contains($0) }
        }
    }

    private func shareNote(noteID: NoteID) throws -> SingleNoteShare {
        guard let note = try noteStore.note(withID: noteID) else {
            throw RuntimeError.noteNotFound(noteID)
        }

        return SingleNoteShare(
            title: note.title,
            filename: "\(filesystemSafeMarkdownBase(from: note.title)).md",
            content: note.body
        )
    }

    private func diagnosticsExport() throws -> DiagnosticsExport {
        let activeNotes = try noteStore.listNotes()
        let allNotes = try noteStore.listNotes(includeTrash: true)
        let graph = try graphStore.trustedGraph(notes: activeNotes)
        let inventory = modelInventory.inventory()
        let operations = aiOperationStore.list()

        return DiagnosticsExport(
            noteIDs: activeNotes.map(\.id),
            activeNoteCount: activeNotes.count,
            trashedNoteCount: allNotes.filter(\.isTrashed).count,
            placeholderNoteCount: activeNotes.filter(\.isPlaceholder).count,
            explicitLinkCount: graph.edges.filter { $0.provenance == .explicitLink }.count,
            acceptedRelationshipCount: graph.edges.filter { $0.provenance == .acceptedRelationship }.count,
            localModelProfiles: inventory.downloadedProfiles.map {
                DiagnosticsModelProfile(id: $0.id, name: $0.name)
            },
            chosenLocalModelProfileID: modelInventory.chosenProfile()?.id,
            aiProgressState: aiProgressState,
            aiOperationIDs: operations.map(\.id),
            aiOperationCount: operations.count
        )
    }

    private func uniqueMarkdownFilename(base: String, usedFilenames: inout Set<String>, nextSuffixByBase: inout [String: Int]) -> String {
        var suffix = nextSuffixByBase[base] ?? 1
        var filename = suffix == 1 ? "\(base).md" : "\(base) (\(suffix)).md"
        while usedFilenames.contains(filename.lowercased()) {
            suffix += 1
            filename = "\(base) (\(suffix)).md"
        }
        usedFilenames.insert(filename.lowercased())
        nextSuffixByBase[base] = suffix + 1
        return filename
    }

    private func filesystemSafeMarkdownBase(from title: String) -> String {
        let titleWithoutExtension = title.lowercased().hasSuffix(".md") ? String(title.dropLast(3)) : title
        let replaced = String(titleWithoutExtension.map { character in
            isUnsafeFilenameCharacter(character) ? "-" : character
        })
        let collapsed = replaced.split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " .-"))

        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func isUnsafeFilenameCharacter(_ character: Character) -> Bool {
        let unsafeCharacters: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
        return unsafeCharacters.contains(character) || character.unicodeScalars.contains { $0.value < 32 }
    }

    private func markdownTitle(from path: String) -> String {
        let fileName = path.split { $0 == "/" || $0 == "\\" }.last.map(String.init) ?? path
        if fileName.lowercased().hasSuffix(".md") {
            return String(fileName.dropLast(3))
        }

        return fileName
    }

    private func importedPath(for targetPath: String, from sourcePath: String) -> String {
        if targetPath.hasPrefix("/") {
            return normalizedImportPath(targetPath)
        }
        let sourceParts = normalizedImportPath(sourcePath).split(separator: "/").map(String.init).dropLast()
        return normalizedImportPath((sourceParts + [targetPath]).joined(separator: "/"))
    }

    private func normalizedImportPath(_ path: String) -> String {
        var parts: [String] = []
        for part in path.replacingOccurrences(of: "\\", with: "/").split(separator: "/") {
            if part == "." {
                continue
            }
            if part == ".." {
                _ = parts.popLast()
            } else {
                parts.append(String(part))
            }
        }
        return parts.joined(separator: "/")
    }

    private func retrievedNotes(for prompt: String) throws -> [Note] {
        let activeNotesByID = Dictionary(uniqueKeysWithValues: try noteStore.listNotes().map { ($0.id, $0) })
        var seen = Set<NoteID>()
        var context: [Note] = []

        func append(_ noteID: NoteID) {
            guard let note = activeNotesByID[noteID], !note.isPlaceholder else {
                return
            }
            guard seen.insert(note.id).inserted else {
                return
            }

            context.append(note)
        }

        let seedNoteIDs = try retrievalSeeds(for: prompt).filter { noteID in
            activeNotesByID[noteID]?.isPlaceholder == false
        }
        for noteID in seedNoteIDs {
            append(noteID)
        }
        for noteID in seedNoteIDs {
            for targetNoteID in try graphStore.explicitLinkTargets(from: noteID) {
                append(targetNoteID)
            }
        }
        for noteID in seedNoteIDs {
            for targetNoteID in try graphStore.acceptedRelationshipTargets(from: noteID) {
                append(targetNoteID)
            }
        }

        return context
    }

    /// Seed Notes for retrieval: semantic (embedding) search when a provider is
    /// configured, otherwise the lexical UserSearchIndex. The fallback keeps
    /// retrieval working before the embedding model/index is ready.
    private func retrievalSeeds(for prompt: String) throws -> [NoteID] {
        guard let provider = noteEmbeddingProvider, noteEmbeddingIndex.isReady else {
            return userSearchIndex.search(prompt)
        }
        let queryVector = try provider.embed(prompt)
        return noteEmbeddingIndex.search(
            queryVector: queryVector,
            topK: Self.embeddingSearchTopK,
            threshold: Self.embeddingSearchThreshold
        )
    }
}
