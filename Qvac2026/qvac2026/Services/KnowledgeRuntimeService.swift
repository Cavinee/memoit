import Foundation
import QVACRuntime

struct PresentationHomeNoteGroup {
    let title: String
    let notes: [Note]
}

struct PresentationHomeNoteList {
    let pinnedNotes: [Note]
    let groups: [PresentationHomeNoteGroup]
}

struct PresentationAnswer {
    let answer: String
    let mode: AnswerMode
    let modeLabel: String
    let isConstrainedToRetrievedNotes: Bool
    let citations: [PresentationSourceCitation]
}

@MainActor
final class KnowledgeRuntimeService {
    static let shared = KnowledgeRuntimeService()

    private let runtime: OnDeviceKnowledgeRuntime?
    private(set) var runtimeStartupError: Error?
    private let database: DatabaseService
    private let noteIDMappingStore: RuntimeNoteIDMappingStore?
    private var hydrated = false

    init(
        runtime: OnDeviceKnowledgeRuntime? = nil,
        runtimeStartupError: Error? = nil,
        database: DatabaseService? = nil
    ) {
        var resolvedRuntime: OnDeviceKnowledgeRuntime?
        var resolvedStartupError = runtimeStartupError

        if let runtime {
            resolvedRuntime = runtime
        } else {
            do {
                resolvedRuntime = try KnowledgeRuntimeService.makeDefaultRuntime()
            } catch {
                resolvedStartupError = error
                print("KnowledgeRuntimeService persistent runtime unavailable: \(error)")
            }
        }

        if resolvedRuntime != nil {
            do {
                noteIDMappingStore = try RuntimeNoteIDMappingStore(
                    storageURL: KnowledgeRuntimeService.runtimeStorageURL()
                )
            } catch {
                resolvedRuntime = nil
                resolvedStartupError = error
                noteIDMappingStore = nil
                print("KnowledgeRuntimeService Note ID mapping unavailable: \(error)")
            }
        } else {
            noteIDMappingStore = nil
        }

        self.runtime = resolvedRuntime
        self.runtimeStartupError = resolvedStartupError
        self.database = database ?? .shared
    }

    func activeNotes() -> [Note] {
        ensureHydrated()
        do {
            return try mirrorRuntimeNotes(try activeRuntimeNotes())
        } catch {
            print("KnowledgeRuntimeService activeNotes error: \(error)")
            return []
        }
    }

    func homeNoteList() -> PresentationHomeNoteList {
        ensureHydrated()
        do {
            let runtime = try requireRuntime()
            guard case .homeNotes(let homeNoteList) = try runtime.query(.homeNotes) else {
                throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
            }

            return PresentationHomeNoteList(
                pinnedNotes: try mirrorRuntimeNotes(homeNoteList.pinnedNotes),
                groups: try homeNoteList.groups.map { group in
                    PresentationHomeNoteGroup(title: group.title, notes: try mirrorRuntimeNotes(group.notes))
                }
            )
        } catch {
            print("KnowledgeRuntimeService homeNoteList error: \(error)")
            return PresentationHomeNoteList(pinnedNotes: [], groups: [])
        }
    }

    func trashedNotes() -> [Note] {
        ensureHydrated()
        do {
            return try mirrorRuntimeNotes(try trashedRuntimeNotes())
        } catch {
            print("KnowledgeRuntimeService trashedNotes error: \(error)")
            return []
        }
    }

    func search(query: String) -> [Note] {
        ensureHydrated()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activeNotes() }

        do {
            let runtime = try requireRuntime()
            guard case .userSearchResults(let runtimeNotes) = try runtime.query(.userSearch(trimmed)) else {
                throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
            }

            return try mirrorRuntimeNotes(runtimeNotes)
        } catch {
            print("KnowledgeRuntimeService search error: \(error)")
            return []
        }
    }

    func trustedGraph() -> PresentationTrustedGraph {
        ensureHydrated()
        do {
            let runtime = try requireRuntime()
            guard case .trustedGraph(let runtimeGraph) = try runtime.query(.trustedGraph) else {
                throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
            }

            for node in runtimeGraph.nodes {
                if let runtimeNote = try runtimeNote(with: node.noteID, in: runtime) {
                    _ = try mirror(runtimeNote)
                }
            }

            return try PresentationTrustedGraph(runtimeGraph: runtimeGraph) { noteID in
                try appID(for: noteID)
            }
        } catch {
            print("KnowledgeRuntimeService trustedGraph error: \(error)")
            return PresentationTrustedGraph(nodes: [], edges: [])
        }
    }

    func answer(prompt: String, mode: AnswerMode = .noteGrounded) throws -> PresentationAnswer {
        ensureHydrated()
        let runtime = try requireRuntime()

        if mode == .noteGrounded {
            refreshUserSearchIndex()
        }
        try ensureDevelopmentLocalModelProfileIfNeeded(in: runtime)

        let result = try runtime.answer(AnswerRequest(prompt: prompt, mode: mode))
        return PresentationAnswer(
            answer: result.answer,
            mode: result.mode,
            modeLabel: result.modeLabel,
            isConstrainedToRetrievedNotes: result.isConstrainedToRetrievedNotes,
            citations: try result.citations.map { citation in
                PresentationSourceCitation(
                    citation: citation,
                    noteTitle: try runtimeNote(with: citation.noteID, in: runtime)?.title
                )
            }
        )
    }

    // The real answer call blocks on the worklet, whose reply arrives on the main
    // queue — so the blocking work has to run off the main thread or it deadlocks.
    // MainActor prep happens here; the blocking call is dispatched to a background queue.
    func answerAsync(prompt: String, mode: AnswerMode = .noteGrounded) async throws -> PresentationAnswer {
        ensureHydrated()
        let runtime = try requireRuntime()

        if mode == .noteGrounded {
            refreshUserSearchIndex()
        }
        try ensureDevelopmentLocalModelProfileIfNeeded(in: runtime)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AnswerResult, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Refresh the model inventory from the real adapter first; best-effort,
                    // since answer() still gates on the existing inventory if the probe fails.
                    _ = try? runtime.execute(.refreshModelAvailabilityFromAdapter(.init()))
                    let answerResult = try runtime.answer(AnswerRequest(prompt: prompt, mode: mode))
                    continuation.resume(returning: answerResult)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Map citations back on the main actor (runtimeNote lookups touch runtime).
        return PresentationAnswer(
            answer: result.answer,
            mode: result.mode,
            modeLabel: result.modeLabel,
            isConstrainedToRetrievedNotes: result.isConstrainedToRetrievedNotes,
            citations: try result.citations.map { citation in
                PresentationSourceCitation(
                    citation: citation,
                    noteTitle: try runtimeNote(with: citation.noteID, in: runtime)?.title
                )
            }
        )
    }

    func aiSessionHistory() -> [PresentationAISessionHistoryEntry] {
        ensureHydrated()
        do {
            let runtime = try requireRuntime()
            guard case .aiSessionHistory(let entries) = try runtime.query(.aiSessionHistory) else {
                throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
            }

            return try entries.map { entry in
                try PresentationAISessionHistoryEntry(entry: entry) { noteID in
                    try runtimeNote(with: noteID, in: runtime)?.title
                }
            }
        } catch {
            print("KnowledgeRuntimeService aiSessionHistory error: \(error)")
            return []
        }
    }

    func deleteAISessionHistoryEntry(id: AISessionHistoryEntryID) throws {
        ensureHydrated()
        let runtime = try requireRuntime()
        guard case .deletedAISessionHistoryEntry = try runtime.execute(.deleteAISessionHistoryEntry(.init(entryID: id))) else {
            throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
        }
    }

    func note(id: UUID) -> Note? {
        ensureHydrated()
        return database.notes.fetch(id: id)
    }

    @discardableResult
    func saveNote(
        id: UUID,
        title: String,
        body: String,
        contentRTF: Data?,
        type: NoteType,
        pinned: Bool = false
    ) -> Note? {
        ensureHydrated()

        do {
            let runtime = try requireRuntime()
            let noteID = try runtimeNoteID(for: id)
            let workflow = RuntimeNoteEditorSaveWorkflow(
                noteID: noteID,
                title: title,
                body: body
            )
            let runtimeNote = try workflow.save(into: runtime)

            refreshUserSearchIndex()
            scheduleEmbeddingBackfill()
            try rememberMapping(noteID: runtimeNote.id, appID: id)
            if pinned && !runtimeNote.isPinned {
                let pinnedRuntimeNote = try updatedRuntimeNote(from: runtime.execute(.setPinnedNote(.init(
                    noteID: runtimeNote.id,
                    isPinned: true
                ))))
                return try mirror(pinnedRuntimeNote, contentRTF: contentRTF, type: type)
            }
            return try mirror(runtimeNote, contentRTF: contentRTF, type: type)
        } catch RuntimeNoteEditorSaveWorkflowError.discardedEmptyNote {
            return nil
        } catch {
            print("KnowledgeRuntimeService saveNote error: \(error)")
            return nil
        }
    }

    func setPinned(id: UUID, pinned: Bool) {
        ensureHydrated()

        do {
            let runtime = try requireRuntime()
            let noteID = try runtimeNoteID(for: id)
            let runtimeNote = try updatedRuntimeNote(from: runtime.execute(.setPinnedNote(.init(
                noteID: noteID,
                isPinned: pinned
            ))))
            _ = try mirror(runtimeNote)
        } catch {
            print("KnowledgeRuntimeService setPinned error: \(error)")
        }
    }

    func moveToTrash(id: UUID) {
        ensureHydrated()

        do {
            let runtime = try requireRuntime()
            let noteID = try runtimeNoteID(for: id)
            _ = try runtime.execute(.moveNoteToTrash(.init(noteID: noteID)))
            if let runtimeNote = try runtimeNote(with: noteID, in: runtime) {
                _ = try mirror(runtimeNote)
            }
            refreshUserSearchIndex()
            scheduleEmbeddingBackfill()
        } catch {
            print("KnowledgeRuntimeService moveToTrash error: \(error)")
        }
    }

    func restoreFromTrash(id: UUID) {
        ensureHydrated()

        do {
            let runtime = try requireRuntime()
            let noteID = try runtimeNoteID(for: id)
            _ = try runtime.execute(.restoreNoteFromTrash(.init(noteID: noteID)))
            if let runtimeNote = try runtimeNote(with: noteID, in: runtime) {
                _ = try mirror(runtimeNote)
            }
            refreshUserSearchIndex()
            scheduleEmbeddingBackfill()
        } catch {
            print("KnowledgeRuntimeService restoreFromTrash error: \(error)")
        }
    }

    func permanentlyDelete(id: UUID) {
        ensureHydrated()

        do {
            let runtime = try requireRuntime()
            let noteID = try runtimeNoteID(for: id)
            _ = try runtime.execute(.permanentlyDeleteNote(.init(
                noteID: noteID,
                deletionConfirmation: DeletionConfirmation(noteID: noteID)
            )))
            refreshUserSearchIndex()
            scheduleEmbeddingBackfill()
            database.notes.permanentlyDelete(id: try appID(for: noteID))
            try forgetMapping(noteID: noteID)
        } catch {
            print("KnowledgeRuntimeService permanentlyDelete error: \(error)")
        }
    }

    func emptyTrash() {
        let notes = trashedNotes()
        for note in notes {
            permanentlyDelete(id: note.id)
        }
    }

    private func ensureHydrated() {
        guard !hydrated else { return }
        hydrated = true

        refreshPresentationMirror()
        refreshUserSearchIndex()
        // Backfill embeddings once after hydrate so existing notes get embedded off the
        // main thread; subsequent note mutations each schedule their own backfill.
        scheduleEmbeddingBackfill()
    }

    private func mirror(
        _ runtimeNote: QVACRuntime.Note,
        contentRTF: Data? = nil,
        type: NoteType = .text
    ) throws -> Note {
        let appID = try appID(for: runtimeNote.id)
        let existing = database.notes.fetch(id: appID)
        let now = Date()
        let deletedAt = runtimeNote.isTrashed ? (existing?.deletedAt ?? now) : nil
        let mirrored = Note(
            id: appID,
            title: runtimeNote.title,
            preview: String(runtimeNote.body.prefix(100)),
            content: runtimeNote.body,
            contentRTF: contentRTF ?? existing?.contentRTF,
            type: existing?.type ?? type,
            createdAt: existing?.createdAt ?? runtimeNote.lastEditedAt,
            updatedAt: runtimeNote.lastEditedAt,
            deletedAt: deletedAt,
            pinned: runtimeNote.isPinned
        )

        if existing == nil {
            database.notes.insert(mirrored)
        } else if shouldUpdateMirror(existing: existing!, mirrored: mirrored) {
            database.notes.update(mirrored)
        }

        return database.notes.fetch(id: appID) ?? mirrored
    }

    private func mirrorRuntimeNotes(_ runtimeNotes: [QVACRuntime.Note]) throws -> [Note] {
        try runtimeNotes.map { runtimeNote in
            try mirror(runtimeNote)
        }
    }

    private func refreshPresentationMirror() {
        do {
            let activeNotes = try activeRuntimeNotes()
            let trashedNotes = try trashedRuntimeNotes()
            _ = try mirrorRuntimeNotes(activeNotes + trashedNotes)
        } catch {
            print("KnowledgeRuntimeService refreshPresentationMirror error: \(error)")
        }
    }

    private func activeRuntimeNotes() throws -> [QVACRuntime.Note] {
        let runtime = try requireRuntime()
        guard case .homeNotes(let homeNoteList) = try runtime.query(.homeNotes) else {
            throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
        }
        return homeNoteList.pinnedNotes + homeNoteList.groups.flatMap(\.notes)
    }

    private func trashedRuntimeNotes() throws -> [QVACRuntime.Note] {
        let runtime = try requireRuntime()
        guard case .trashedNotes(let notes) = try runtime.query(.trashedNotes) else {
            throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
        }
        return notes
    }

    private func shouldUpdateMirror(existing: Note, mirrored: Note) -> Bool {
        existing.title != mirrored.title ||
        existing.preview != mirrored.preview ||
        existing.content != mirrored.content ||
        existing.contentRTF != mirrored.contentRTF ||
        existing.type != mirrored.type ||
        existing.updatedAt != mirrored.updatedAt ||
        existing.deletedAt != mirrored.deletedAt ||
        existing.pinned != mirrored.pinned
    }

    private func runtimeNoteID(for appID: UUID) throws -> NoteID {
        guard let noteIDMappingStore else {
            throw KnowledgeRuntimeServiceError.runtimeUnavailable(runtimeStartupError)
        }
        return try noteIDMappingStore.noteID(for: appID) ?? NoteID(appID.uuidString)
    }

    private func runtimeNote(with noteID: NoteID, in runtime: OnDeviceKnowledgeRuntime) throws -> QVACRuntime.Note? {
        guard case .note(let note) = try runtime.query(.note(noteID)) else {
            throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
        }
        return note
    }

    private func updatedRuntimeNote(from result: RuntimeCommandResult) throws -> QVACRuntime.Note {
        guard case .updatedNote(let note) = result else {
            throw KnowledgeRuntimeServiceError.unexpectedRuntimeResult
        }
        return note
    }

    // Rebuilds ONLY the lexical user-search index, synchronously on the main actor.
    // This is the cheap freshness pass the answer path gates on, so it must stay
    // inline. Crucially it uses `.lexicalOnly`, so it never triggers the embedding
    // provider's blocking `embed()` — whose worklet reply is delivered on the main
    // queue and would deadlock if called from the main thread. The embedding index is
    // (re)built separately and off the main thread via `scheduleEmbeddingBackfill()`.
    private func refreshUserSearchIndex() {
        do {
            let runtime = try requireRuntime()
            _ = try runtime.execute(.runIndexingJobs(.init(scope: .lexicalOnly)))
        } catch {
            print("KnowledgeRuntimeService refreshUserSearchIndex error: \(error)")
        }
    }

    // Serial background queue that runs the embedding backfill. Serial so concurrent
    // backfills (e.g. several quick saves) are coalesced into a sequence rather than
    // racing; only one `embeddingOnly` rebuild touches the provider/store at a time.
    private let embeddingIndexingQueue = DispatchQueue(label: "com.qvac.embedding-indexing")

    // Rebuilds ONLY the embedding index, OFF the main thread. The production provider's
    // `embed()` blocks on the worklet, whose reply is delivered on the main queue, so it
    // MUST NOT run on the main thread — dispatching here onto a background queue is what
    // keeps the worklet round-trip from deadlocking against the main-queue reply.
    //
    // Concurrency safety of this off-main pass:
    //  - The embedding index itself is lock-protected (Part A): this background rebuild
    //    publishes `records`/`isReady` under a lock, so a concurrent `answerAsync`
    //    (which reads the index on its own background queue) snapshots it safely.
    //  - The SQLite note store is opened FULLMUTEX, so the background `listNotes()` this
    //    pass performs is safe against main-actor note writes. The view is eventually
    //    consistent: a note added mid-backfill is embedded on the NEXT backfill, which
    //    its own save schedules — so nothing is permanently missed.
    //  - The embedding store's contentHash staleness check means only changed notes
    //    actually re-embed, so calling this after every note mutation is cheap (unchanged
    //    notes reuse their stored vectors). This could be coalesced/debounced later if the
    //    per-mutation listNotes()+loadAll() ever shows up in a profile.
    //
    // `runtime` is captured directly (not via `self`/the main actor) so the closure does
    // not hop back onto the main actor; the runtime command runs entirely off-main.
    private func scheduleEmbeddingBackfill() {
        guard let runtime else { return }
        embeddingIndexingQueue.async {
            try? runtime.execute(.runIndexingJobs(.init(scope: .embeddingOnly)))
        }
    }

    private func ensureDevelopmentLocalModelProfileIfNeeded(in runtime: OnDeviceKnowledgeRuntime) throws {
        #if DEBUG
        guard DevelopmentModelProfilePolicy.isOptedIn() else {
            return
        }
        guard case .chosenLocalModelProfile(nil) = try runtime.query(.chosenLocalModelProfile) else {
            return
        }
        _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
            id: .init("local-development-qvac"),
            name: "Local Development QVAC",
            isDownloaded: true,
            isRemovable: false
        ))))
        #endif
    }

    private func requireRuntime() throws -> OnDeviceKnowledgeRuntime {
        guard let runtime else {
            throw KnowledgeRuntimeServiceError.runtimeUnavailable(runtimeStartupError)
        }
        return runtime
    }

    private func appID(for noteID: NoteID) throws -> UUID {
        guard let noteIDMappingStore else {
            throw KnowledgeRuntimeServiceError.runtimeUnavailable(runtimeStartupError)
        }
        return try noteIDMappingStore.appID(for: noteID)
    }

    private func rememberMapping(noteID: NoteID, appID: UUID) throws {
        try noteIDMappingStore?.remember(noteID: noteID, appID: appID)
    }

    private func forgetMapping(noteID: NoteID) throws {
        try noteIDMappingStore?.forget(noteID: noteID)
    }

    private static func makeDefaultRuntime() throws -> OnDeviceKnowledgeRuntime {
        #if targetEnvironment(simulator)
        // Simulator: QVAC on-device SDK is not available; use fake adapter so all
        // runtime features (notes, search, graph) work normally in the simulator.
        return try RuntimeCoreHarness.makeSQLiteBacked(
            storageURL: runtimeStorageURL()
        )
        #else
        // Physical device: attempt to inject the production embedded host adapter.
        // If ExpoModulesCore is not linked (non-Expo build) we fall back to the fake
        // adapter so the app never crashes when the host is absent.
        #if canImport(ExpoModulesCore)
        let adapter = ProductionEmbeddedQVACHostAdapter(
            bridge: ProductionEmbeddedQVACHostBridgeAdapter()
        )
        return try RuntimeCoreHarness.makeSQLiteBacked(
            storageURL: runtimeStorageURL(),
            aiRuntimeAdapter: adapter,
            // Only the real-device branch has a worklet to reach; the simulator and
            // non-Expo branches must stay on the lexical fallback (no worklet there).
            noteEmbeddingProvider: ProductionNoteEmbeddingProvider()
        )
        #else
        return try RuntimeCoreHarness.makeSQLiteBacked(
            storageURL: runtimeStorageURL()
        )
        #endif
        #endif
    }

    private static func runtimeStorageRoot() throws -> URL {
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("QVAC", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func runtimeStorageURL() throws -> URL {
        try runtimeStorageRoot().appendingPathComponent("qvac-runtime.sqlite")
    }
}

private enum KnowledgeRuntimeServiceError: Error {
    case unexpectedRuntimeResult
    case runtimeUnavailable(Error?)
}
