import QVACRuntime
import Foundation
import Darwin
import SQLite3

struct BehaviorTestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ description: String) throws {
    if !condition() {
        throw BehaviorTestFailure(description: description)
    }
}

func expectRuntimeError(_ expected: RuntimeError, _ work: () throws -> Void) throws {
    do {
        try work()
    } catch let error as RuntimeError {
        try expect(error == expected, "expected \(expected), got \(error)")
        return
    }

    throw BehaviorTestFailure(description: "expected \(expected)")
}

func expectEmbeddedQVACHostStatusError(
    _ expected: ProductionIOSEmbeddedQVACHostStatusBridgeError,
    _ work: () async throws -> Void
) async throws {
    do {
        try await work()
    } catch let error as ProductionIOSEmbeddedQVACHostStatusBridgeError {
        try expect(error == expected, "expected \(expected), got \(error)")
        return
    }

    throw BehaviorTestFailure(description: "expected \(expected)")
}

func temporarySQLiteStorageURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("qvac-runtime-\(UUID().uuidString).sqlite")
}

func executeSQLite(_ sql: String, storageURL: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(storageURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        throw BehaviorTestFailure(description: "failed to open SQLite database for test")
    }
    defer { sqlite3_close(database) }
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
        throw BehaviorTestFailure(description: "failed to execute SQLite test SQL: \(message)")
    }
}

func createdNote(from result: RuntimeCommandResult) throws -> Note {
    switch result {
    case .createdNote(let note):
        return note
    default:
        throw BehaviorTestFailure(description: "expected created Note command result")
    }
}

func updatedNote(from result: RuntimeCommandResult) throws -> Note {
    switch result {
    case .updatedNote(let note):
        return note
    default:
        throw BehaviorTestFailure(description: "expected updated Note command result")
    }
}

func discardedEmptyNote(from result: RuntimeCommandResult) throws {
    guard case .discardedEmptyNote = result else {
        throw BehaviorTestFailure(description: "expected discarded empty Note command result")
    }
}

func renamedNote(from result: RuntimeCommandResult) throws -> Note {
    switch result {
    case .renamedNote(let note):
        return note
    default:
        throw BehaviorTestFailure(description: "expected renamed Note command result")
    }
}

func explicitLinks(from result: RuntimeQueryResult) throws -> [ExplicitLink] {
    switch result {
    case .explicitLinks(let links):
        return links
    default:
        throw BehaviorTestFailure(description: "expected Explicit Links query result")
    }
}

func notes(from result: RuntimeQueryResult) throws -> [Note] {
    switch result {
    case .notes(let notes):
        return notes
    default:
        throw BehaviorTestFailure(description: "expected Notes query result")
    }
}

func homeNoteList(from result: RuntimeQueryResult) throws -> HomeNoteList {
    switch result {
    case .homeNotes(let homeNoteList):
        return homeNoteList
    default:
        throw BehaviorTestFailure(description: "expected Home Note List query result")
    }
}

func trashedNotes(from result: RuntimeQueryResult) throws -> [Note] {
    switch result {
    case .trashedNotes(let notes):
        return notes
    default:
        throw BehaviorTestFailure(description: "expected trashed Notes query result")
    }
}

func note(from result: RuntimeQueryResult) throws -> Note? {
    switch result {
    case .note(let note):
        return note
    default:
        throw BehaviorTestFailure(description: "expected Note query result")
    }
}

func backlinks(from result: RuntimeQueryResult) throws -> [Backlink] {
    switch result {
    case .backlinks(let backlinks):
        return backlinks
    default:
        throw BehaviorTestFailure(description: "expected Backlinks query result")
    }
}

func trustedGraph(from result: RuntimeQueryResult) throws -> TrustedGraph {
    switch result {
    case .trustedGraph(let graph):
        return graph
    default:
        throw BehaviorTestFailure(description: "expected Trusted Graph query result")
    }
}

func suggestedRelationships(from result: RuntimeCommandResult) throws -> [SuggestedRelationship] {
    switch result {
    case .suggestedRelationships(let relationships):
        return relationships
    default:
        throw BehaviorTestFailure(description: "expected Suggested Relationships command result")
    }
}

func acceptedRelationship(from result: RuntimeCommandResult) throws -> AcceptedRelationship {
    switch result {
    case .createdAcceptedRelationship(let relationship):
        return relationship
    default:
        throw BehaviorTestFailure(description: "expected Accepted Relationship command result")
    }
}

func userSearchResults(from result: RuntimeQueryResult) throws -> [Note] {
    switch result {
    case .userSearchResults(let notes):
        return notes
    default:
        throw BehaviorTestFailure(description: "expected User Search query result")
    }
}

func indexFreshness(from result: RuntimeQueryResult) throws -> IndexFreshness {
    switch result {
    case .indexFreshness(let freshness):
        return freshness
    default:
        throw BehaviorTestFailure(description: "expected Index Freshness query result")
    }
}

func aiReadyDevice(from result: RuntimeQueryResult) throws -> Bool {
    switch result {
    case .aiReadyDevice(let isReady):
        return isReady
    default:
        throw BehaviorTestFailure(description: "expected AI-ready Device query result")
    }
}

func aiUnavailableState(from result: RuntimeQueryResult) throws -> AIUnavailableState? {
    switch result {
    case .aiUnavailableState(let state):
        return state
    default:
        throw BehaviorTestFailure(description: "expected AI Unavailable State query result")
    }
}

func localModelProfile(from result: RuntimeCommandResult) throws -> LocalModelProfile {
    switch result {
    case .recordedLocalModelProfile(let profile):
        return profile
    default:
        throw BehaviorTestFailure(description: "expected Local Model Profile command result")
    }
}

func modelInventory(from result: RuntimeQueryResult) throws -> ModelInventory {
    switch result {
    case .modelInventory(let inventory):
        return inventory
    default:
        throw BehaviorTestFailure(description: "expected Model Inventory query result")
    }
}

func updatedModelInventory(from result: RuntimeCommandResult) throws -> ModelInventory {
    switch result {
    case .updatedModelInventory(let inventory):
        return inventory
    default:
        throw BehaviorTestFailure(description: "expected updated Model Inventory command result")
    }
}

func chosenLocalModelProfile(from result: RuntimeQueryResult) throws -> LocalModelProfile? {
    switch result {
    case .chosenLocalModelProfile(let profile):
        return profile
    default:
        throw BehaviorTestFailure(description: "expected chosen Local Model Profile query result")
    }
}

func aiProgressState(from result: RuntimeQueryResult) throws -> AIProgressState {
    switch result {
    case .aiProgressState(let state):
        return state
    default:
        throw BehaviorTestFailure(description: "expected AI Progress State query result")
    }
}

func aiSessionHistory(from result: RuntimeQueryResult) throws -> [AISessionHistoryEntry] {
    switch result {
    case .aiSessionHistory(let entries):
        return entries
    default:
        throw BehaviorTestFailure(description: "expected AI Session History query result")
    }
}

func movedNoteToTrash(from result: RuntimeCommandResult) throws -> (Note, TrashUndoOpportunity) {
    switch result {
    case .movedNoteToTrash(let note, let undo):
        return (note, undo)
    default:
        throw BehaviorTestFailure(description: "expected moved Note to Trash command result")
    }
}

func restoredNote(from result: RuntimeCommandResult) throws -> Note {
    switch result {
    case .restoredNote(let note):
        return note
    default:
        throw BehaviorTestFailure(description: "expected restored Note command result")
    }
}

func permanentlyDeletedNoteID(from result: RuntimeCommandResult) throws -> NoteID {
    switch result {
    case .permanentlyDeletedNote(let noteID):
        return noteID
    default:
        throw BehaviorTestFailure(description: "expected permanently deleted Note command result")
    }
}

func deletedAISessionHistoryEntryID(from result: RuntimeCommandResult) throws -> AISessionHistoryEntryID {
    switch result {
    case .deletedAISessionHistoryEntry(let entryID):
        return entryID
    default:
        throw BehaviorTestFailure(description: "expected deleted AI Session History entry command result")
    }
}

func savedAIResponse(from result: RuntimeCommandResult) throws -> SavedAIResponse {
    switch result {
    case .savedAIResponse(let savedResponse):
        return savedResponse
    default:
        throw BehaviorTestFailure(description: "expected Saved AI Response command result")
    }
}

func reversedAIOperation(from result: RuntimeCommandResult) throws -> AIOperation {
    switch result {
    case .reversedAIOperation(let operation):
        return operation
    default:
        throw BehaviorTestFailure(description: "expected reversed AI Operation command result")
    }
}

func aiWriteWorkflow(from result: RuntimeCommandResult) throws -> AIWriteWorkflowResult {
    switch result {
    case .aiWriteWorkflow(let workflowResult):
        return workflowResult
    default:
        throw BehaviorTestFailure(description: "expected AI Write Workflow command result")
    }
}

func acceptedDraftChangeOperation(from result: RuntimeCommandResult) throws -> AIOperation {
    switch result {
    case .acceptedDraftChange(let operation):
        return operation
    default:
        throw BehaviorTestFailure(description: "expected accepted Draft Change command result")
    }
}

func canceledDraftChangeID(from result: RuntimeCommandResult) throws -> DraftChangeID {
    switch result {
    case .canceledDraftChange(let draftChangeID):
        return draftChangeID
    default:
        throw BehaviorTestFailure(description: "expected canceled Draft Change command result")
    }
}

func incompleteAIOperationID(from result: RuntimeCommandResult) throws -> AIOperationID {
    switch result {
    case .beganIncompleteAIOperation(let operationID):
        return operationID
    default:
        throw BehaviorTestFailure(description: "expected incomplete AI Operation command result")
    }
}

func aiOperations(from result: RuntimeQueryResult) throws -> [AIOperation] {
    switch result {
    case .aiOperations(let operations):
        return operations
    default:
        throw BehaviorTestFailure(description: "expected AI Operations query result")
    }
}

func markdownImport(from result: RuntimeCommandResult) throws -> MarkdownImportResult {
    switch result {
    case .importedMarkdown(let importResult):
        return importResult
    default:
        throw BehaviorTestFailure(description: "expected Markdown Import command result")
    }
}

func markdownExport(from result: RuntimeQueryResult) throws -> MarkdownExportResult {
    switch result {
    case .markdownExport(let exportResult):
        return exportResult
    default:
        throw BehaviorTestFailure(description: "expected Markdown Export query result")
    }
}

func markdownExportBundle(from result: RuntimeQueryResult) throws -> MarkdownExportBundle {
    switch result {
    case .exportBundle(let bundle):
        return bundle
    default:
        throw BehaviorTestFailure(description: "expected Export Bundle query result")
    }
}

func singleNoteShare(from result: RuntimeQueryResult) throws -> SingleNoteShare {
    switch result {
    case .singleNoteShare(let share):
        return share
    default:
        throw BehaviorTestFailure(description: "expected Single-note Share query result")
    }
}

func diagnosticsExport(from result: RuntimeQueryResult) throws -> DiagnosticsExport {
    switch result {
    case .diagnosticsExport(let export):
        return export
    default:
        throw BehaviorTestFailure(description: "expected Diagnostics Export query result")
    }
}

func diagnosticsExportIsUserInitiatedAndContentFree() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sensitiveTitle = "Therapy Door Code"
    let sensitiveBody = "pin 1234 lives here"
    let sensitivePrompt = "summarize my private therapy note"
    let importPath = "Vault/Secrets/Bank.md"
    let importedBody = "routing number 000"
    let profile = LocalModelProfile(id: .init("model-a"), name: "QVAC Tiny")

    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: sensitiveTitle,
        body: sensitiveBody,
        creationProvenance: .userCreated
    ))))
    let imported = try markdownImport(from: runtime.execute(.importMarkdownFile(.init(
        file: MarkdownImportFile(path: importPath, body: importedBody)
    )))).notes[0]
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))
    let answer = try runtime.answer(.init(prompt: sensitivePrompt, mode: .general))

    let export = try diagnosticsExport(from: runtime.query(.diagnosticsExport))
    let text = String(describing: export)

    try expect(export == DiagnosticsExport(
        noteIDs: [created.id, imported.id],
        activeNoteCount: 2,
        trashedNoteCount: 0,
        placeholderNoteCount: 0,
        explicitLinkCount: 0,
        acceptedRelationshipCount: 0,
        localModelProfiles: [
            DiagnosticsModelProfile(id: profile.id, name: profile.name)
        ],
        chosenLocalModelProfileID: profile.id,
        aiProgressState: .idle,
        aiOperationIDs: [],
        aiOperationCount: 0
    ), "Diagnostics Export should include content-free runtime metadata")
    try expect(!text.contains(sensitiveTitle), "Diagnostics Export should exclude Note Titles")
    try expect(!text.contains(sensitiveBody), "Diagnostics Export should exclude Note Bodies")
    try expect(!text.contains(importPath), "Diagnostics Export should exclude import paths")
    try expect(!text.contains(importedBody), "Diagnostics Export should exclude imported Note Bodies")
    try expect(!text.contains(sensitivePrompt), "Diagnostics Export should exclude AI Session History prompts")
    try expect(!text.contains(answer.answer), "Diagnostics Export should exclude AI Session History responses")
}

func contentFreeLogEntryAcceptsAllowedOperationalMetadata() throws {
    let entry = ContentFreeLogEntry(fields: [
        .id: .string("note-1"),
        .count: .int(2),
        .durationMilliseconds: .int(37),
        .modelProfileName: .string("QVAC Tiny"),
        .jobState: .string("indexed"),
        .errorCategory: .string("ai-unavailable"),
        .storageBytes: .int(4096)
    ])

    try expect(entry.fields == [
        .id: .string("note-1"),
        .count: .int(2),
        .durationMilliseconds: .int(37),
        .modelProfileName: .string("QVAC Tiny"),
        .jobState: .string("indexed"),
        .errorCategory: .string("ai-unavailable"),
        .storageBytes: .int(4096)
    ], "Content-free Logs should accept IDs, counts, durations, model profile names, job states, error categories, and storage sizes")
}

func contentFreeLogEntryRejectsForbiddenContentFields() throws {
    let forbiddenFields = [
        "noteText",
        "noteTitle",
        "noteBody",
        "prompt",
        "response",
        "citation",
        "filename",
        "importPath",
        "aiSessionHistory"
    ]

    for field in forbiddenFields {
        do {
            _ = try ContentFreeLogEntry(validating: [
                field: .string("secret")
            ])
            throw BehaviorTestFailure(description: "expected Content-free Log to reject \(field)")
        } catch let error as ContentFreeLogError {
            try expect(error == .forbiddenField(field), "Content-free Log should reject \(field)")
        }
    }
}

func crashReportPayloadIsOptionalAndContentFree() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sensitivePrompt = "private crash prompt"
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    let answer = try runtime.answer(.init(prompt: sensitivePrompt, mode: .general))

    let payload: CrashReportPayload? = CrashReportPayload(
        errorCategory: "ai-unavailable",
        count: 1,
        state: "idle"
    )
    let text = String(describing: payload)

    try expect(payload == CrashReportPayload(
        errorCategory: "ai-unavailable",
        count: 1,
        state: "idle"
    ), "Crash Report payload should include only content-free error category, count, and state")
    try expect(!text.contains(sensitivePrompt), "Crash Report payload should exclude AI Session History prompts")
    try expect(!text.contains(answer.answer), "Crash Report payload should exclude AI Session History responses")
}

func creatingANoteThroughRuntimeCommandCanBeReadThroughRuntimeQuery() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let commandResult = try runtime.execute(.createNote(.init(
        title: "Local runtime",
        body: "# Local runtime\n\n[[Wikilinks]] stay raw.",
        creationProvenance: .userCreated
    )))

    let createdNote = try createdNote(from: commandResult)

    try expect(createdNote.title == "Local runtime", "created Note Title should match")
    try expect(createdNote.body == "# Local runtime\n\n[[Wikilinks]] stay raw.", "created Note Body should preserve raw Markdown")
    try expect(createdNote.creationProvenance == .userCreated, "created Note should retain Creation Provenance")

    let queryResult = try runtime.query(.note(createdNote.id))

    switch queryResult {
    case .note(let note):
        try expect(note == createdNote, "read Note should match created Note")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func creatingANoteCanPreserveAHostSuppliedNoteID() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let requestedID = NoteID("9D01A643-420F-4B84-A21F-C79DF1202291")

    let commandResult = try runtime.execute(.createNote(.init(
        noteID: requestedID,
        title: "Host-created note",
        body: "Created from the Native iOS App",
        creationProvenance: .userCreated
    )))
    let created = try createdNote(from: commandResult)
    let stored = try note(from: runtime.query(.note(requestedID)))

    try expect(created.id == requestedID, "created Note should preserve the host-supplied Note ID")
    try expect(stored == created, "host-supplied Note ID should be queryable through the runtime")
}

func sqliteBackedRuntimePersistsCreatedNoteAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let noteID = NoteID("note-a")
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)

    let created = try createdNote(from: runtimeA.execute(.createNote(.init(
        noteID: noteID,
        title: "Alpha",
        body: "Body",
        creationProvenance: .userCreated
    ))))

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let persisted = try note(from: runtimeB.query(.note(noteID)))

    try expect(persisted == created, "SQLite-backed runtime should persist created Notes across runtime instances")
}

func sqliteBackedRuntimePreservesNoteFieldsAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let importedID = NoteID("imported-note")

    let importResult = try markdownImport(from: runtimeA.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Bundle/Imported.md", body: "Imported body")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Bundle/Imported.md": importedID
            ],
            importProvenanceByPath: [
                "Bundle/Imported.md": ImportProvenance(sourcePath: "Original/Imported.md")
            ]
        )
    )))))
    let imported = importResult.notes[0]
    let trashedImported = try movedNoteToTrash(from: runtimeA.execute(.moveNoteToTrash(.init(noteID: imported.id)))).0
    _ = try runtimeA.execute(.createNote(.init(
        title: "Source",
        body: "See [[Future]].",
        creationProvenance: .userCreated
    )))
    guard let placeholder = try notes(from: runtimeA.query(.notes)).first(where: { $0.title == "Future" }) else {
        throw BehaviorTestFailure(description: "test setup should create a Placeholder Note")
    }

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let persistedImported = try note(from: runtimeB.query(.note(importedID)))
    let persistedPlaceholder = try note(from: runtimeB.query(.note(placeholder.id)))

    try expect(trashedImported.id.rawValue == "imported-note", "SQLite-backed runtime should preserve Note ID raw values")
    try expect(persistedImported == trashedImported, "SQLite-backed runtime should preserve imported Note fields and Trash state")
    try expect(persistedImported?.importProvenance?.sourcePath == "Original/Imported.md", "SQLite-backed runtime should preserve Import Provenance source paths")
    try expect(persistedPlaceholder == placeholder, "SQLite-backed runtime should preserve Placeholder Note fields")
    try expect(persistedPlaceholder?.isPlaceholder == true, "SQLite-backed runtime should preserve Placeholder state")
}

func sqliteBackedRuntimeSupportsNoteLifecycleAndSearchAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let noteID = NoteID("fixed-id")
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)

    let created = try createdNote(from: runtimeA.execute(.createNote(.init(
        noteID: noteID,
        title: "Alpha",
        body: "Basalt body",
        creationProvenance: .userCreated
    ))))
    let updated = try updatedNote(from: runtimeA.execute(.updateNoteBody(.init(
        noteID: created.id,
        body: "Basalt revised body"
    ))))
    let renamed = try renamedNote(from: runtimeA.execute(.renameNote(.init(
        noteID: updated.id,
        title: "Renamed Alpha"
    ))))
    _ = try runtimeA.execute(.runIndexingJobs(.init()))
    let activeNotesBeforeTrash = try notes(from: runtimeA.query(.notes))
    let searchResultsBeforeTrash = try userSearchResults(from: runtimeA.query(.userSearch("revised")))

    try expect(activeNotesBeforeTrash == [renamed], "SQLite-backed runtime should list active Notes after create, update, and rename")
    try expect(searchResultsBeforeTrash == [renamed], "SQLite-backed runtime should search active Note body text")

    let trashed = try movedNoteToTrash(from: runtimeA.execute(.moveNoteToTrash(.init(noteID: noteID)))).0
    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let persistedTrashed = try note(from: runtimeB.query(.note(noteID)))
    let activeNotesAfterTrash = try notes(from: runtimeB.query(.notes))
    let searchResultsAfterTrash = try userSearchResults(from: runtimeB.query(.userSearch("revised")))

    try expect(persistedTrashed == trashed, "SQLite-backed runtime should persist Trash state")
    try expect(activeNotesAfterTrash.isEmpty, "SQLite-backed runtime should exclude Trash from active Notes after relaunch")
    try expect(searchResultsAfterTrash.isEmpty, "SQLite-backed runtime should exclude Trash from User Search after relaunch")

    let restored = try restoredNote(from: runtimeB.execute(.restoreNoteFromTrash(.init(noteID: noteID))))
    let runtimeC = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let activeNotesAfterRestore = try notes(from: runtimeC.query(.notes))
    let searchResultsAfterRestore = try userSearchResults(from: runtimeC.query(.userSearch("revised")))

    try expect(restored.isTrashed == false, "SQLite-backed runtime restore should make the Note active")
    try expect(activeNotesAfterRestore == [restored], "SQLite-backed runtime should persist restored active state")
    try expect(searchResultsAfterRestore == [restored], "SQLite-backed runtime should include restored Notes in User Search after relaunch")

    _ = try runtimeC.execute(.moveNoteToTrash(.init(noteID: noteID)))
    let deletedID = try permanentlyDeletedNoteID(from: runtimeC.execute(.permanentlyDeleteNote(.init(
        noteID: noteID,
        deletionConfirmation: DeletionConfirmation(noteID: noteID)
    ))))
    let runtimeD = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let persistedAfterDelete = try note(from: runtimeD.query(.note(noteID)))

    try expect(deletedID == noteID, "SQLite-backed runtime should return the permanently deleted Note ID")
    try expect(persistedAfterDelete == nil, "SQLite-backed runtime should persist permanent deletion")
}

func sqliteBackedRuntimeDisambiguatesTitlesAgainstPersistedNotes() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)

    _ = try runtimeA.execute(.createNote(.init(
        title: "Daily",
        body: "one",
        creationProvenance: .userCreated
    )))
    _ = try runtimeA.execute(.createNote(.init(
        title: "Daily",
        body: "two",
        creationProvenance: .userCreated
    )))

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let third = try createdNote(from: runtimeB.execute(.createNote(.init(
        title: "Daily",
        body: "three",
        creationProvenance: .userCreated
    ))))
    let persistedTitles = try notes(from: runtimeB.query(.notes)).map(\.title)

    try expect(third.title == "Daily (3)", "SQLite-backed runtime should disambiguate titles against persisted Notes")
    try expect(persistedTitles == ["Daily", "Daily (2)", "Daily (3)"], "SQLite-backed runtime should preserve the existing disambiguation pattern")
}

func sqliteBackedRuntimeListsTrashedNotesAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let note = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Trash me",
        body: "recoverable",
        creationProvenance: .userCreated
    ))))
    let trashed = try movedNoteToTrash(from: runtimeA.execute(.moveNoteToTrash(.init(noteID: note.id)))).0

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let active = try notes(from: runtimeB.query(.notes))
    let trash = try trashedNotes(from: runtimeB.query(.trashedNotes))

    try expect(active.isEmpty, "SQLite-backed runtime active Notes query should exclude Trash after relaunch")
    try expect(trash == [trashed], "SQLite-backed runtime should list trashed Notes after relaunch")
}

func pinnedNotesPersistAndAppearAboveRegularHomeGroupsAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL, clock: { now })

    let pinned = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Pinned",
        body: "priority",
        creationProvenance: .userCreated
    ))))
    now = Date(timeIntervalSince1970: 1_700_000_060)
    let regular = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Regular",
        body: "normal",
        creationProvenance: .userCreated
    ))))
    _ = try runtimeA.execute(.setPinnedNote(.init(noteID: pinned.id, isPinned: true)))

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL, clock: { now })
    let persistedPinned = try note(from: runtimeB.query(.note(pinned.id)))
    let home = try homeNoteList(from: runtimeB.query(.homeNotes))

    try expect(persistedPinned?.isPinned == true, "Pinned Note state should persist in the runtime")
    try expect(home.pinnedNotes.map(\.id) == [pinned.id], "Home Note List should put Pinned Notes in the pinned section after relaunch")
    try expect(home.groups.flatMap(\.notes).map(\.id) == [regular.id], "Home Note List should keep unpinned Notes in regular Last Edited Time groups")
}

func regularHomeGroupsUseRuntimeLastEditedTimeOrdering() throws {
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    var now = base.addingTimeInterval(-259_200)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })

    let older = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Older",
        body: "old body",
        creationProvenance: .userCreated
    ))))
    let editedLater = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Edited later",
        body: "first body",
        creationProvenance: .userCreated
    ))))
    now = base
    let updatedLater = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
        noteID: editedLater.id,
        body: "new body"
    ))))

    let home = try homeNoteList(from: runtime.query(.homeNotes))

    try expect(updatedLater.lastEditedAt == base, "updating Note Body should advance Last Edited Time")
    try expect(home.pinnedNotes.isEmpty, "test setup should have no Pinned Notes")
    try expect(home.groups.map(\.title) == ["TODAY", "A WEEK AGO"], "regular Home Note List Groups should be based on Last Edited Time")
    try expect(home.groups.map { $0.notes.map(\.id) } == [[editedLater.id], [older.id]], "regular Notes should be ordered newest Last Edited Time first within Home groups")
}

func emptyUserCreatedNotesAreDiscardedWhilePlaceholderNotesRemainSupported() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    try discardedEmptyNote(from: runtime.execute(.createNote(.init(
        title: "   ",
        body: "\n  ",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let notesAfterDiscard = try notes(from: runtime.query(.notes))
    let searchAfterDiscard = try userSearchResults(from: runtime.query(.userSearch("anything")))

    try expect(notesAfterDiscard.isEmpty, "empty user-created Notes should not be durably created")
    try expect(searchAfterDiscard.isEmpty, "discarded empty Notes should not appear in User Search")

    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Source",
        body: "Follow [[Placeholder]].",
        creationProvenance: .userCreated
    ))))
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "Placeholder" }) else {
        throw BehaviorTestFailure(description: "unresolved Wikilink should still create a Placeholder Note")
    }
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(placeholder.body.isEmpty, "Placeholder Notes should remain supported with an empty Note Body")
    try expect(placeholder.isPlaceholder, "Placeholder Notes should retain Placeholder state")
    try expect(graph.nodes.contains(TrustedGraphNode(noteID: placeholder.id, title: placeholder.title, isPlaceholder: true)), "Placeholder Notes should remain graph-visible")
    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: placeholder.id, provenance: .explicitLink)
    ], "Placeholder Notes should keep Explicit Links in the Trusted Graph")
}

func userCreatedNoteDraftDiscardPolicyRequiresEmptyTitleAndBody() throws {
    try expect(
        !UserCreatedNoteDraftDiscardPolicy.shouldDiscard(title: "Project Plan", body: "\n  "),
        "title-only user-created Note drafts should not be discarded"
    )
    try expect(
        UserCreatedNoteDraftDiscardPolicy.shouldDiscard(title: "   ", body: "\n  "),
        "user-created Note drafts with empty title and body should be discarded"
    )
}

func textFirstV1PolicyDisablesAttachmentAndMultimodalEntryPoints() throws {
    let disabledEntryPoints: [TextFirstV1EntryPoint] = [
        .audioRecording,
        .cameraCapture,
        .photoPicker,
        .documentFilePicker,
        .microphone,
        .ocr,
        .transcription,
        .attachment
    ]

    for entryPoint in disabledEntryPoints {
        try expect(
            !TextFirstV1Policy.isEnabled(entryPoint),
            "\(entryPoint) should be inactive in v1"
        )
        try expect(
            !TextFirstV1Policy.allowsAttachmentRecordCreation(from: entryPoint),
            "\(entryPoint) should not create Future Attachment records in v1"
        )
        try expect(
            !TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: entryPoint),
            "\(entryPoint) should not mutate authoritative Note Body in v1"
        )
    }

    try expect(
        TextFirstV1Policy.isEnabled(.textInput),
        "text input should remain enabled in v1"
    )
    try expect(
        TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: .textInput),
        "text input should remain able to mutate authoritative Note Body"
    )
    try expect(
        TextFirstV1Policy.isEnabled(.markdownTable),
        "Supported Markdown tables should remain enabled in v1"
    )
    try expect(
        TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: .markdownTable),
        "Supported Markdown tables should remain Note Body content, not managed attachments"
    )
    try expect(
        !TextFirstV1Policy.allowsAttachmentRecordCreation(from: .markdownTable),
        "Supported Markdown tables should not create Future Attachment records"
    )
}

func textFirstV1PolicyRejectsArchivedTablePresentationState() throws {
    try expect(
        !TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "\u{FFFC}",
            runtimeBody: ""
        ),
        "archived table attachments should not restore when the runtime Note Body is empty"
    )
    try expect(
        !TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "Intro\u{FFFC}\nOutro",
            runtimeBody: "Intro\nOutro"
        ),
        "archived table attachments should not restore when stripped archive text matches runtime Note Body"
    )
    try expect(
        TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "# Heading",
            runtimeBody: "# Heading"
        ),
        "matching non-table presentation state may restore as disposable editor state"
    )
    try expect(
        !TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "Archive body",
            runtimeBody: "Runtime body"
        ),
        "mismatched archived presentation state should not override runtime Note Body"
    )
}

func textFirstV1PolicyRejectsArchivedObjectReplacementPresentationState() throws {
    try expect(
        !TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "Intro\u{FFFC}\nOutro",
            runtimeBody: "Intro\nOutro"
        ),
        "archived presentation state with object replacement characters should not restore when stripped text matches runtime Note Body"
    )
    try expect(
        TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "# Heading",
            runtimeBody: "# Heading"
        ),
        "matching archived presentation text without object replacement characters may restore as disposable editor state"
    )
    try expect(
        !TextFirstV1Policy.shouldRestoreArchivedPresentationState(
            archivedPresentationText: "Archived",
            runtimeBody: "Runtime"
        ),
        "mismatched archived presentation text should not override runtime Note Body"
    )
}

func textFirstV1PolicyCoversAppEntryPointMappings() throws {
    let disabledAppEntryPoints: [TextFirstV1AppEntryPoint] = [
        .noteStartRecording,
        .noteStopRecording,
        .noteAddImage,
        .noteAddFile,
        .noteCameraCapture,
        .notePhotoPicker,
        .noteMicrophone,
        .notePersistedAttachments,
        .chatAttachment,
        .chatMicrophone
    ]

    for entryPoint in disabledAppEntryPoints {
        try expect(
            !TextFirstV1Policy.isEnabled(entryPoint),
            "\(entryPoint) should be inactive in v1 app surfaces"
        )
        try expect(
            !TextFirstV1Policy.allowsAttachmentRecordCreation(from: entryPoint),
            "\(entryPoint) should not create Future Attachment records"
        )
        try expect(
            !TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: entryPoint),
            "\(entryPoint) should not mutate authoritative Note Body"
        )
    }

    try expect(
        TextFirstV1Policy.isEnabled(.noteTextInput),
        "Note text input should remain enabled"
    )
    try expect(
        TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: .noteTextInput),
        "Note text input should continue to mutate authoritative Note Body"
    )
    try expect(
        !TextFirstV1Policy.allowsAttachmentRecordCreation(from: .noteTextInput),
        "Note text input should not create Future Attachment records"
    )
    try expect(
        TextFirstV1Policy.isEnabled(.noteMarkdownTable),
        "Note Markdown table insertion should remain enabled"
    )
    try expect(
        TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: .noteMarkdownTable),
        "Note Markdown table insertion should mutate raw Markdown Note Body"
    )
    try expect(
        !TextFirstV1Policy.allowsAttachmentRecordCreation(from: .noteMarkdownTable),
        "Note Markdown table insertion should not create Future Attachment records"
    )
}

func textFirstV1AppGuardMakesExactNoteAndChatDecisions() throws {
    let disabledDecisions: [(TextFirstV1AppEntryPoint, Bool)] = [
        (.notePersistedAttachments, TextFirstV1AppGuard.canLoadPersistedAttachments()),
        (.noteStartRecording, TextFirstV1AppGuard.canStartRecording()),
        (.noteStopRecording, TextFirstV1AppGuard.canStopRecordingAndCreateAttachment()),
        (.noteAddImage, TextFirstV1AppGuard.canAddImageAttachment()),
        (.noteAddFile, TextFirstV1AppGuard.canAddFileAttachment()),
        (.chatMicrophone, TextFirstV1AppGuard.canUseChatMicrophone()),
        (.chatAttachment, TextFirstV1AppGuard.canUseChatAttachment())
    ]

    for (entryPoint, helperResult) in disabledDecisions {
        let decision = TextFirstV1AppGuard.decision(for: entryPoint)
        try expect(!helperResult, "\(entryPoint) helper should disable this app entry point")
        try expect(!decision.isEnabled, "\(entryPoint) should be disabled by the app guard")
        try expect(!decision.allowsAttachmentRecordCreation, "\(entryPoint) should not create Future Attachment records")
        try expect(!decision.allowsRuntimeNoteBodyMutation, "\(entryPoint) should not mutate authoritative Note Body")
    }

    let textDecision = TextFirstV1AppGuard.decision(for: .noteTextInput)
    try expect(TextFirstV1AppGuard.canPersistNoteTextInput(), "note text input helper should remain enabled")
    try expect(textDecision.isEnabled, "note text input should be enabled by the app guard")
    try expect(!textDecision.allowsAttachmentRecordCreation, "note text input should not create Future Attachment records")
    try expect(textDecision.allowsRuntimeNoteBodyMutation, "note text input should mutate authoritative Note Body")

    let tableDecision = TextFirstV1AppGuard.decision(for: .noteMarkdownTable)
    try expect(TextFirstV1AppGuard.canInsertMarkdownTable(), "Markdown table helper should remain enabled")
    try expect(tableDecision.isEnabled, "Markdown table insertion should be enabled by the app guard")
    try expect(!tableDecision.allowsAttachmentRecordCreation, "Markdown table insertion should not create Future Attachment records")
    try expect(tableDecision.allowsRuntimeNoteBodyMutation, "Markdown table insertion should mutate raw Markdown Note Body")
}

func supportedMarkdownRoundTripsHeadings() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .heading(level: 1, text: [.plain("Heading 1")]),
        .heading(level: 2, text: [.plain("Heading 2")]),
        .heading(level: 3, text: [.plain("Heading 3")])
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(
        markdown == """
        # Heading 1

        ## Heading 2

        ### Heading 3
        """,
        "Supported Markdown should serialize heading levels 1 through 3"
    )
    try expect(reloaded == document, "Supported Markdown should reload heading levels 1 through 3")
}

func supportedMarkdownRoundTripsInlineFormattingAndHtmlAllowlist() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .paragraph(text: [
            .plain("A "),
            SupportedMarkdownInline(text: "bold", styles: [.bold]),
            .plain(" "),
            SupportedMarkdownInline(text: "italic", styles: [.italic]),
            .plain(" "),
            SupportedMarkdownInline(text: "underlined", styles: [.underline]),
            .plain(" "),
            SupportedMarkdownInline(text: "strike", styles: [.strikethrough]),
            .plain(" "),
            SupportedMarkdownInline(text: "inline", styles: [.inlineCode]),
            .plain(" [[Testing]]")
        ])
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)
    let unsupportedHTML = SupportedMarkdownDocument(markdown: "<span>x</span> <script>x</script>")

    try expect(
        markdown == "A **bold** *italic* <u>underlined</u> ~~strike~~ `inline` [[Testing]]",
        "Supported Markdown should serialize inline v1 formatting and literal Wikilinks"
    )
    try expect(reloaded == document, "Supported Markdown should reload inline v1 formatting")
    try expect(
        unsupportedHTML == SupportedMarkdownDocument(blocks: [
            .paragraph(text: [.plain("<span>x</span> <script>x</script>")])
        ]),
        "arbitrary inline HTML should remain literal text, not supported formatting"
    )
}

func supportedMarkdownEditorBridgeKeepsLiteralBoldMarkersPlain() throws {
    let presentation = SupportedMarkdownEditorPresentation(blocks: [
        .paragraph(inline: [.plain("Use **literal** markers")])
    ])

    let markdown = SupportedMarkdownEditorBridge.markdown(from: presentation)
    let reloaded = SupportedMarkdownEditorBridge.presentation(markdown: markdown)

    try expect(
        reloaded == presentation,
        "plain editor text containing bold markers should reload as plain text, not bold formatting"
    )
}

func supportedMarkdownEditorBridgeKeepsLiteralInlineMarkersPlain() throws {
    let presentation = SupportedMarkdownEditorPresentation(blocks: [
        .paragraph(inline: [
            .plain("*literal* ~~literal~~ `literal` <u>literal</u>")
        ])
    ])

    let markdown = SupportedMarkdownEditorBridge.markdown(from: presentation)
    let reloaded = SupportedMarkdownEditorBridge.presentation(markdown: markdown)

    try expect(
        reloaded == presentation,
        "plain editor text containing inline markers should reload as plain text, not formatting"
    )
}

func supportedMarkdownEditorBridgeKeepsLiteralHeadingMarkerParagraphPlain() throws {
    let presentation = SupportedMarkdownEditorPresentation(blocks: [
        .paragraph(inline: [.plain("# literal heading marker")])
    ])

    let markdown = SupportedMarkdownEditorBridge.markdown(from: presentation)
    let reloaded = SupportedMarkdownEditorBridge.presentation(markdown: markdown)

    try expect(
        reloaded == presentation,
        "plain editor text beginning with a heading marker should reload as paragraph text"
    )
}

func supportedMarkdownEditorBridgeKeepsLiteralBlockMarkersParagraphPlain() throws {
    let literalParagraphs = [
        "> literal quote marker",
        "- literal bullet marker",
        "1. literal numbered marker",
        "---",
        "| not | a | table |"
    ]

    for literalParagraph in literalParagraphs {
        let presentation = SupportedMarkdownEditorPresentation(blocks: [
            .paragraph(inline: [.plain(literalParagraph)])
        ])

        let markdown = SupportedMarkdownEditorBridge.markdown(from: presentation)
        let reloaded = SupportedMarkdownEditorBridge.presentation(markdown: markdown)

        try expect(
            reloaded == presentation,
            "plain editor text beginning with \(literalParagraph) should reload as paragraph text"
        )
    }
}

func supportedMarkdownEditorBridgeCreatesTitleBasedWikilinkInsertionText() throws {
    try expect(
        SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: "Runtime Core") == "[[Runtime Core]]",
        "editor note-link insertion should emit title-based Wikilink syntax"
    )
    try expect(
        SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: "Runtime\nCore") == nil,
        "editor note-link insertion should reject Note Titles containing newlines"
    )
    try expect(
        SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: "Runtime ]] Core") == nil,
        "editor note-link insertion should reject Note Titles that would close the Wikilink early"
    )
}

func supportedMarkdownRoundTripsBoldItalicInlineCombination() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .paragraph(text: [
            SupportedMarkdownInline(text: "text", styles: [.bold, .italic])
        ])
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(markdown == "***text***", "Supported Markdown should serialize bold+italic inline text")
    try expect(reloaded == document, "Supported Markdown should reload bold+italic inline text")
}

func supportedMarkdownRoundTripsBoldUnderlineInlineCombination() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .paragraph(text: [
            SupportedMarkdownInline(text: "text", styles: [.bold, .underline])
        ])
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(markdown == "**<u>text</u>**", "Supported Markdown should serialize bold+underline inline text")
    try expect(reloaded == document, "Supported Markdown should reload bold+underline inline text")
}

func supportedMarkdownRoundTripsUnderlineStrikethroughInlineCombination() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .paragraph(text: [
            SupportedMarkdownInline(text: "text", styles: [.underline, .strikethrough])
        ])
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(markdown == "<u>~~text~~</u>", "Supported Markdown should serialize underline+strikethrough inline text")
    try expect(reloaded == document, "Supported Markdown should reload underline+strikethrough inline text")
}

func supportedMarkdownRoundTripsBlockFormatting() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .blockQuote(text: [.plain("quote")]),
        .divider,
        .fencedCodeBlock(language: nil, code: "let x = 1\nprint(x)")
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(
        markdown == """
        > quote

        ---

        ```
        let x = 1
        print(x)
        ```
        """,
        "Supported Markdown should serialize block quote, divider, and fenced code block syntax"
    )
    try expect(reloaded == document, "Supported Markdown should reload block quote, divider, and fenced code block syntax")
}

func supportedMarkdownRoundTripsFencedCodeLanguageAndBlankLines() throws {
    let markdown = """
    ```swift
    let x = 1

    print(x)
    ```
    """
    let document = SupportedMarkdownDocument(markdown: markdown)

    try expect(
        document == SupportedMarkdownDocument(blocks: [
            .fencedCodeBlock(language: "swift", code: "let x = 1\n\nprint(x)")
        ]),
        "Supported Markdown should parse a fenced code block with language and internal blank lines as one block"
    )
    try expect(
        document.markdown() == markdown,
        "Supported Markdown should serialize fenced code block language and internal blank lines unchanged"
    )
}

func supportedMarkdownRoundTripsListsAndTables() throws {
    let document = SupportedMarkdownDocument(blocks: [
        .bulletList(items: [[.plain("item")]]),
        .checklist(items: [
            SupportedMarkdownChecklistItem(isChecked: false, text: [.plain("todo")]),
            SupportedMarkdownChecklistItem(isChecked: true, text: [.plain("done")])
        ]),
        .numberedList(start: 1, items: [[.plain("item")]]),
        .table(SupportedMarkdownTable(header: ["A", "B"], rows: [["1", "2"]]))
    ])

    let markdown = document.markdown()
    let reloaded = SupportedMarkdownDocument(markdown: markdown)

    try expect(
        markdown == """
        - item

        - [ ] todo
        - [x] done

        1. item

        | A | B |
        | --- | --- |
        | 1 | 2 |
        """,
        "Supported Markdown should serialize lists, checklists, numbered lists, and pipe tables"
    )
    try expect(reloaded == document, "Supported Markdown should reload lists, checklists, numbered lists, and pipe tables")
}

func supportedMarkdownEditorPresentationReloadsFormattingFamilies() throws {
    let markdown = """
    # Heading 1

    ## Heading 2

    ### Heading 3

    A **bold** *italic* <u>underlined</u> ~~strike~~ `inline` [[Testing]] <span>x</span> <script>x</script>

    > quote

    ---

    ```
    let x = 1
    print(x)
    ```

    - item

    - [ ] todo
    - [x] done

    1. item

    | A | B |
    | --- | --- |
    | 1 | 2 |
    """

    let presentation = SupportedMarkdownEditorPresentation(markdown: markdown)

    try expect(
        presentation == SupportedMarkdownEditorPresentation(blocks: [
            .heading(level: 1, inline: [.plain("Heading 1")]),
            .heading(level: 2, inline: [.plain("Heading 2")]),
            .heading(level: 3, inline: [.plain("Heading 3")]),
            .paragraph(inline: [
                .plain("A "),
                SupportedMarkdownPresentationInline(text: "bold", styles: [.bold]),
                .plain(" "),
                SupportedMarkdownPresentationInline(text: "italic", styles: [.italic]),
                .plain(" "),
                SupportedMarkdownPresentationInline(text: "underlined", styles: [.underline]),
                .plain(" "),
                SupportedMarkdownPresentationInline(text: "strike", styles: [.strikethrough]),
                .plain(" "),
                SupportedMarkdownPresentationInline(text: "inline", styles: [.inlineCode]),
                .plain(" [[Testing]] <span>x</span> <script>x</script>")
            ]),
            .blockQuote(inline: [.plain("quote")]),
            .divider,
            .fencedCodeBlock(language: nil, code: "let x = 1\nprint(x)"),
            .bulletList(items: [[.plain("item")]]),
            .checklist(items: [
                SupportedMarkdownPresentationChecklistItem(isChecked: false, inline: [.plain("todo")]),
                SupportedMarkdownPresentationChecklistItem(isChecked: true, inline: [.plain("done")])
            ]),
            .numberedList(start: 1, items: [[.plain("item")]]),
            .table(SupportedMarkdownTable(header: ["A", "B"], rows: [["1", "2"]]))
        ]),
        "Supported Markdown editor presentation should restore supported formatting families while keeping arbitrary HTML literal"
    )
}

func supportedMarkdownEditorBridgePreservesFencedCodeLanguageAcrossReloadAndSave() throws {
    let markdown = """
    ```swift
    let x = 1
    ```
    """

    let presentation = SupportedMarkdownEditorBridge.presentation(markdown: markdown)
    let savedMarkdown = SupportedMarkdownEditorBridge.markdown(from: presentation)

    try expect(
        presentation == SupportedMarkdownEditorPresentation(blocks: [
            .fencedCodeBlock(language: "swift", code: "let x = 1")
        ]),
        "Supported Markdown editor bridge should reload fenced code block language"
    )
    try expect(
        savedMarkdown == markdown,
        "Supported Markdown editor bridge should save fenced code block language after reload"
    )
}

func supportedMarkdownEditorBridgePreservesReloadedFencedCodeBlankLinesAcrossEditorBufferSave() throws {
    let markdown = """
    ```swift
    let a = 1

    let b = 2
    ```
    """

    let editorBuffer = SupportedMarkdownEditorBridge.editorContent(markdown: markdown)
    let savedMarkdown = SupportedMarkdownEditorBridge.markdown(fromEditorContent: editorBuffer)

    try expect(
        editorBuffer.text == "let a = 1\n\nlet b = 2",
        "Supported Markdown editor bridge should model reloaded fenced code as editor text with internal blank lines"
    )
    try expect(
        savedMarkdown == markdown,
        "Supported Markdown editor bridge should save a reloaded fenced code block with internal blank lines as one code block"
    )
}

func supportedMarkdownEditorBridgeKeepsTypedFencedCodeBlankLinesInOneBlockRange() throws {
    let typedMarkdown = """
    ```swift
    let a = 1

    let b = 2
    ```
    """

    let ranges = SupportedMarkdownEditorBridge.blockRanges(
        in: typedMarkdown,
        protectedRanges: []
    )

    try expect(
        ranges == [SupportedMarkdownEditorTextRange(
            location: 0,
            length: (typedMarkdown as NSString).length
        )],
        "Supported Markdown editor bridge should keep raw typed fenced code with internal blank lines in one block range"
    )

    let blockText = (typedMarkdown as NSString).substring(with: NSRange(
        location: ranges[0].location,
        length: ranges[0].length
    ))
    let document = SupportedMarkdownDocument(markdown: blockText)

    try expect(
        document == SupportedMarkdownDocument(blocks: [
            .fencedCodeBlock(language: "swift", code: "let a = 1\n\nlet b = 2")
        ]),
        "Supported Markdown editor save path should parse raw typed fenced code with internal blank lines as one fenced code block"
    )
    try expect(
        document.markdown() == typedMarkdown,
        "Supported Markdown editor save path should preserve raw typed fenced code language and internal blank lines"
    )
}

func supportedMarkdownEditorBridgeSavesPlainEditorParagraphBlockMarkersWithoutShapePromotion() throws {
    let literalParagraphs = [
        "---",
        "1. literal numbered marker",
        "> literal quote marker",
        "| not | a | table |",
        "# literal heading marker",
        "- literal bullet marker"
    ]

    for literalParagraph in literalParagraphs {
        let block = SupportedMarkdownEditorBridge.blockFromEditorParagraph(
            text: literalParagraph,
            inline: [.plain(literalParagraph)],
            intent: nil
        )

        try expect(
            block == .paragraph(text: [.plain(literalParagraph)]),
            "plain editor paragraph \(literalParagraph) should save as a paragraph without raw-shape promotion"
        )
    }
}

func supportedMarkdownEditorBridgeSavesExplicitEditorBlockIntentAsFormatting() throws {
    let table = SupportedMarkdownTable(header: ["A", "B"], rows: [["1", "2"]])
    let cases: [(SupportedMarkdownEditorBlockIntent, SupportedMarkdownBlock)] = [
        (.heading(level: 2), .heading(level: 2, text: [.plain("# literal heading marker")])),
        (.blockQuote, .blockQuote(text: [.plain("> literal quote marker")])),
        (.divider, .divider),
        (.fencedCodeBlock(language: "swift"), .fencedCodeBlock(language: "swift", code: "let x = 1")),
        (.bulletList(items: [[.plain("literal bullet marker")]]), .bulletList(items: [[.plain("literal bullet marker")]])),
        (
            .numberedList(start: 1, items: [[.plain("literal numbered marker")]]),
            .numberedList(start: 1, items: [[.plain("literal numbered marker")]])
        ),
        (
            .checklist(items: [SupportedMarkdownChecklistItem(isChecked: false, text: [.plain("todo")])]),
            .checklist(items: [SupportedMarkdownChecklistItem(isChecked: false, text: [.plain("todo")])])
        ),
        (.table(table), .table(table))
    ]

    for (intent, expected) in cases {
        let block = SupportedMarkdownEditorBridge.blockFromEditorParagraph(
            text: editorText(for: expected),
            inline: inlineText(for: expected),
            intent: intent
        )

        try expect(
            block == expected,
            "explicit editor block intent \(intent) should save as supported markdown formatting"
        )
    }
}

private func editorText(for block: SupportedMarkdownBlock) -> String {
    switch block {
    case .paragraph(let text), .heading(_, let text), .blockQuote(let text):
        return text.map(\.text).joined()
    case .divider:
        return "---"
    case .fencedCodeBlock(_, let code):
        return code
    case .bulletList(let items):
        return items.map { "• " + $0.map(\.text).joined() }.joined(separator: "\n")
    case .checklist(let items):
        return items.map { "☐ " + $0.text.map(\.text).joined() }.joined(separator: "\n")
    case .numberedList(let start, let items):
        return items.enumerated()
            .map { offset, item in "\(start + offset). " + item.map(\.text).joined() }
            .joined(separator: "\n")
    case .table(let table):
        return table.markdown()
    }
}

private func inlineText(for block: SupportedMarkdownBlock) -> [SupportedMarkdownInline] {
    switch block {
    case .heading(_, let text), .blockQuote(let text), .paragraph(let text):
        return text
    case .fencedCodeBlock(_, let code):
        return [.plain(code)]
    case .divider, .bulletList, .checklist, .numberedList, .table:
        return [.plain(editorText(for: block))]
    }
}

func richTextEditorUsesRuntimeMarkdownBridgeForReloadAndCodeLanguagePersistence() throws {
    let editorURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Components/RichTextEditor.swift")
    let source = try String(contentsOf: editorURL)

    try expect(
        source.contains("SupportedMarkdownEditorBridge.presentation(markdown: authoritativeBody)"),
        "RichTextController.loadInitialContent should use the SwiftPM-tested runtime presentation bridge"
    )
    try expect(
        source.contains("SupportedMarkdownEditorBridge.markdown(from:"),
        "RichTextController.supportedMarkdownBody should save through the SwiftPM-tested runtime bridge"
    )
    try expect(
        source.contains("case .fencedCodeBlock(let language, let code):"),
        "RichTextController reload bridge should receive fenced code language from runtime presentation"
    )
    try expect(
        source.contains(".qvacSupportedMarkdownCodeLanguage"),
        "RichTextController should retain fenced code language as editor presentation state"
    )
    try expect(
        source.contains("language: attributes[.qvacSupportedMarkdownCodeLanguage] as? String"),
        "RichTextController.supportedMarkdownBody should persist fenced code language from editor presentation state"
    )
}

func richTextEditorSavePathUsesExplicitRuntimeBlockIntentWithoutRawShapePromotion() throws {
    let editorURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Components/RichTextEditor.swift")
    let source = try String(contentsOf: editorURL)
    let markdownBlockSource = try sourceSection(
        in: source,
        startingAt: "private func markdownBlock(in range: NSRange, text: String)",
        endingBefore: "\n    private func bulletList"
    )

    try expect(
        source.contains("SupportedMarkdownEditorBridge.blockFromEditorParagraph("),
        "RichTextController.supportedMarkdownBody should choose blocks through the SwiftPM-tested explicit intent seam"
    )
    try expect(
        !source.contains("if text == \"---\""),
        "RichTextController.supportedMarkdownBody should not promote divider syntax from raw paragraph text"
    )
    try expect(
        !source.contains("SupportedMarkdownDocument(markdown: text).blocks.first"),
        "RichTextController.supportedMarkdownBody should not parse raw paragraph text into block formatting"
    )
    try expect(
        !markdownBlockSource.contains("inferredHeadingLevel(from:"),
        "RichTextController.supportedMarkdownBody should not infer heading intent from visual font shape"
    )
    try expect(
        !source.contains("font.pointSize >="),
        "RichTextController.supportedMarkdownBody should not keep visual font-size heading thresholds"
    )
}

func noteEditorWiresTitleBasedWikilinkInsertionThroughRuntimeSavePath() throws {
    let toolbarURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Components/NoteKeyboardToolbar.swift")
    let bodyURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Components/NoteEditorBody.swift")
    let viewModelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/ViewModel/NoteEditorViewModel.swift")
    let editorURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Components/RichTextEditor.swift")

    let toolbarSource = try String(contentsOf: toolbarURL)
    let bodySource = try String(contentsOf: bodyURL)
    let viewModelSource = try String(contentsOf: viewModelURL)
    let editorSource = try String(contentsOf: editorURL)
    let persistSource = try sourceSection(
        in: viewModelSource,
        startingAt: "func persist() -> Bool",
        endingBefore: "\n    private static func derivedTitle"
    )

    try expect(
        toolbarSource.contains("state.showNoteLinkPicker = true"),
        "Note Keyboard Toolbar should expose a note-linking UI entry point"
    )
    try expect(
        bodySource.contains(".sheet(isPresented: $state.showNoteLinkPicker)") &&
            bodySource.contains("KnowledgeRuntimeService.shared.activeNotes()") &&
            bodySource.contains("state.insertWikilink(to: note)"),
        "Note Editor Body should present active runtime Notes and route a selection to Wikilink insertion"
    )
    try expect(
        viewModelSource.contains("func insertWikilink(to note: Note)") &&
            viewModelSource.contains("SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: note.title)") &&
            viewModelSource.contains("editor.insertWikilink(title: note.title, markdown: wikilink)") &&
            viewModelSource.contains("markChanged()") &&
            viewModelSource.contains("persist()"),
        "Note Editor ViewModel should insert title-based Wikilink text, mark the editor changed, and persist"
    )
    try expect(
        editorSource.contains("func insertWikilink(title: String, markdown: String)") &&
            editorSource.contains("onMentionTrigger") &&
            editorSource.contains("controller.onMentionTrigger?()") &&
            editorSource.contains("resetTypingAttributes: true") &&
            editorSource.contains("tv.typingAttributes = bodyAttributes()") &&
            editorSource.contains("resetTypingAttributesIfNeededBeforeUserInsertion") &&
            editorSource.contains("controller.resetTypingAttributesIfNeededBeforeUserInsertion(in: textView, range: range)"),
        "RichTextController should expose an @ mention trigger, insert Wikilink tokens, and reset typing attributes after token insertion or adjacent loaded-token typing"
    )
    try expect(
        persistSource.contains("let body = editor.supportedMarkdownBody()") &&
            persistSource.contains("KnowledgeRuntimeService.shared.saveNote("),
        "manual unresolved Wikilinks and Placeholder Note promotion should keep using the runtime save path"
    )
}

func productionNoteSaveUsesRuntimeEditorSaveWorkflow() throws {
    let serviceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Qvac2026/qvac2026/Services/KnowledgeRuntimeService.swift")
    let serviceSource = try String(contentsOf: serviceURL)
    let saveNoteSource = try sourceSection(
        in: serviceSource,
        startingAt: "func saveNote(",
        endingBefore: "\n    func setPinned"
    )

    try expect(
        saveNoteSource.contains("RuntimeNoteEditorSaveWorkflow(") &&
            saveNoteSource.contains(".save(into: runtime)"),
        "KnowledgeRuntimeService.saveNote should delegate app editor saves to the runtime editor save workflow"
    )
    try expect(
        !saveNoteSource.contains("runtime.execute(.createNote(") &&
            !saveNoteSource.contains("runtime.execute(.renameNote(") &&
            !saveNoteSource.contains("runtime.execute(.updateNoteBody("),
        "KnowledgeRuntimeService.saveNote should not duplicate the runtime editor create/rename/body-update flow"
    )
}

func noteEditorWorkflowInsertsExistingNoteWikilinkAndPersistsExplicitLink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        noteID: NoteID("note-a"),
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        noteID: NoteID("note-source"),
        title: "Daily Note",
        body: "See this.",
        creationProvenance: .userCreated
    ))))
    var workflow = RuntimeNoteEditorSaveWorkflow(
        noteID: source.id,
        title: source.title,
        body: source.body
    )

    try workflow.insertWikilink(
        to: target,
        replacing: SupportedMarkdownEditorTextRange(location: 4, length: 4)
    )
    let saved = try workflow.save(into: runtime)
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(saved.body == "See [[Runtime Core]].", "editor workflow should persist inserted Wikilink markdown in the source Note Body")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: "See [[Runtime Core]]."
        )
    ], "editor workflow inserted Wikilink should resolve to the existing target Note ID")
}

func noteEditorWorkflowSaveCreatesPlaceholderForManualUnresolvedWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        noteID: NoteID("note-source"),
        title: "Daily Note",
        body: "",
        creationProvenance: .userCreated
    ))))
    let workflow = RuntimeNoteEditorSaveWorkflow(
        noteID: source.id,
        title: source.title,
        body: "Follow [[Missing Note]]."
    )

    let saved = try workflow.save(into: runtime)
    let allNotes = try notes(from: runtime.query(.notes))
    guard let placeholder = allNotes.first(where: { $0.title == "Missing Note" }) else {
        throw BehaviorTestFailure(description: "editor save path should create a visible Placeholder Note for a manual unresolved Wikilink")
    }
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(saved.body == "Follow [[Missing Note]].", "editor save path should persist the manually typed unresolved Wikilink")
    try expect(placeholder.body == "", "editor save path Placeholder Note should start with an empty body")
    try expect(placeholder.isPlaceholder, "editor save path should mark the unresolved target as a Placeholder Note")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: placeholder.id,
            snippet: "Follow [[Missing Note]]."
        )
    ], "editor save path should point the source Explicit Link at the Placeholder Note ID")
}

func noteEditorWorkflowSavePromotesPlaceholderWhenBodyIsAuthored() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        noteID: NoteID("note-source"),
        title: "Daily Note",
        body: "Follow [[Missing Note]].",
        creationProvenance: .userCreated
    ))))
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "Missing Note" }) else {
        throw BehaviorTestFailure(description: "test setup should create a Placeholder Note")
    }
    let workflow = RuntimeNoteEditorSaveWorkflow(
        noteID: placeholder.id,
        title: placeholder.title,
        body: "This is now user-authored content."
    )

    let promoted = try workflow.save(into: runtime)

    try expect(promoted.id == placeholder.id, "editor save path should promote the same Placeholder Note ID")
    try expect(promoted.body == "This is now user-authored content.", "editor save path should persist authored Placeholder body content")
    try expect(!promoted.isPlaceholder, "editor save path should promote a Placeholder Note once body content is authored")
}

private func sourceSection(
    in source: String,
    startingAt startMarker: String,
    endingBefore endMarker: String
) throws -> String {
    guard let start = source.range(of: startMarker)?.lowerBound else {
        throw BehaviorTestFailure(description: "missing source start marker: \(startMarker)")
    }
    guard let end = source[start...].range(of: endMarker)?.lowerBound else {
        throw BehaviorTestFailure(description: "missing source end marker: \(endMarker)")
    }
    return String(source[start..<end])
}

func defaultUserSearchSearchesActiveNotesOnlyAndExcludesTrash() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let trashed = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Trash keyword",
        body: "needle only in trash",
        creationProvenance: .userCreated
    ))))
    let active = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Active keyword",
        body: "needle active",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.moveNoteToTrash(.init(noteID: trashed.id)))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let results = try userSearchResults(from: runtime.query(.userSearch("needle")))

    try expect(results == [active], "Default User Search should search active Notes only and exclude Trash")
}

func sqliteBackedRuntimeDoesNotReuseGeneratedNoteIDsAfterPermanentDeletion() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)

    let first = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "First",
        body: "one",
        creationProvenance: .userCreated
    ))))
    _ = try runtimeA.execute(.moveNoteToTrash(.init(noteID: first.id)))
    _ = try runtimeA.execute(.permanentlyDeleteNote(.init(
        noteID: first.id,
        deletionConfirmation: DeletionConfirmation(noteID: first.id)
    )))

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let second = try createdNote(from: runtimeB.execute(.createNote(.init(
        title: "Second",
        body: "two",
        creationProvenance: .userCreated
    ))))

    try expect(first.id == NoteID("note-1"), "test setup should allocate the first generated Note ID")
    try expect(second.id == NoteID("note-2"), "SQLite-backed runtime should not reuse generated Note IDs after permanent deletion")
}

func sqliteBackedRuntimeSurfacesPersistenceReadErrorsAsThrownRuntimeErrors() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    _ = try runtimeA.execute(.createNote(.init(
        title: "Corrupt me",
        body: "body",
        creationProvenance: .userCreated
    )))
    try executeSQLite("UPDATE notes SET creation_provenance = 'corrupt-value'", storageURL: storageURL)

    do {
        let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
        _ = try runtimeB.query(.notes)
        throw BehaviorTestFailure(description: "expected corrupt persisted Note data to throw")
    } catch is BehaviorTestFailure {
        throw BehaviorTestFailure(description: "expected corrupt persisted Note data to throw")
    } catch {
        return
    }
}

func runtimeNoteIDMappingStorePreservesNonUUIDRuntimeIDsForHostPresentation() throws {
    let storageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("qvac-note-id-map-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeNoteID = NoteID("note-1")
    let uuidBackedNoteID = NoteID("9D01A643-420F-4B84-A21F-C79DF1202291")
    let storeA = try RuntimeNoteIDMappingStore(storageURL: storageURL)

    let appID = try storeA.appID(for: runtimeNoteID)

    let storeB = try RuntimeNoteIDMappingStore(storageURL: storageURL)
    let persistedAppID = try storeB.appID(for: runtimeNoteID)
    let uuidBackedAppID = try storeB.appID(for: uuidBackedNoteID)
    let reverseMappedNoteID = try storeB.noteID(for: appID)

    try expect(appID == persistedAppID, "Runtime Note ID mapping should persist non-UUID runtime IDs across store instances")
    try expect(reverseMappedNoteID == runtimeNoteID, "Runtime Note ID mapping should support reverse lookup for host actions")
    try expect(uuidBackedAppID.uuidString == uuidBackedNoteID.rawValue, "Runtime Note ID mapping should preserve UUID-backed runtime IDs as host UUIDs")

    try storeB.forget(noteID: runtimeNoteID)
    let storeC = try RuntimeNoteIDMappingStore(storageURL: storageURL)
    let forgottenNoteID = try storeC.noteID(for: appID)

    try expect(forgottenNoteID == nil, "Runtime Note ID mapping should remove reverse mappings after permanent deletion")
}

func runtimeNoteIDMappingStoreSharesRuntimeSQLiteFileWithPersistedNotes() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeNoteID = NoteID("note-1")
    let runtime = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Mapped",
        body: "body",
        creationProvenance: .userCreated
    ))))
    let storeA = try RuntimeNoteIDMappingStore(storageURL: storageURL)

    let appID = try storeA.appID(for: runtimeNoteID)

    let storeB = try RuntimeNoteIDMappingStore(storageURL: storageURL)
    let persistedAppID = try storeB.appID(for: runtimeNoteID)
    let persistedNote = try note(from: RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL).query(.note(runtimeNoteID)))
    let reverseMappedNoteID = try storeB.noteID(for: appID)

    try expect(created.id == runtimeNoteID, "test setup should create generated runtime Note ID")
    try expect(appID == persistedAppID, "Runtime Note ID mapping should persist in the runtime SQLite file")
    try expect(reverseMappedNoteID == runtimeNoteID, "Runtime Note ID mapping should support reverse lookup from the same SQLite file")
    try expect(persistedNote == created, "Runtime Note ID mapping table should coexist with persisted Notes in the same SQLite file")
}

func runtimeNoteIDMappingStoreSurfacesReverseLookupReadErrors() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeNoteID = NoteID("note-1")
    let store = try RuntimeNoteIDMappingStore(storageURL: storageURL)
    let appID = try store.appID(for: runtimeNoteID)
    try executeSQLite("DROP TABLE runtime_note_id_mappings", storageURL: storageURL)

    do {
        _ = try store.noteID(for: appID)
        throw BehaviorTestFailure(description: "expected reverse mapping lookup to throw when SQLite read fails")
    } catch is BehaviorTestFailure {
        throw BehaviorTestFailure(description: "expected reverse mapping lookup to throw when SQLite read fails")
    } catch {
        return
    }
}

func importingIndividualMarkdownFileCreatesNoteWithRawBodyAndProvenance() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFile(.init(
        file: MarkdownImportFile(path: "Ideas.md", body: "hello")
    ))))
    guard let imported = importResult.notes.first else {
        throw BehaviorTestFailure(description: "Markdown Import should return the imported Note")
    }

    let stored = try note(from: runtime.query(.note(imported.id)))

    try expect(importResult.notes == [imported], "single-file Markdown Import should return the created Note")
    try expect(imported.title == "Ideas", "Markdown Import should derive Note Title from filename")
    try expect(imported.body == "hello", "Markdown Import should preserve raw Note Body")
    try expect(imported.creationProvenance == .imported, "Markdown Import should mark imported Creation Provenance")
    try expect(imported.importProvenance == ImportProvenance(sourcePath: "Ideas.md"), "Markdown Import should store Import Provenance on the Note")
    try expect(importResult.provenance == [imported.id: ImportProvenance(sourcePath: "Ideas.md")], "Markdown Import result should summarize Import Provenance")
    try expect(stored == imported, "imported Note should be readable through Runtime Query")
}

func importingMarkdownFolderCreatesFlatDisambiguatedNotesWithoutReplacingExistingNotes() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let existing = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Ideas",
        body: "original",
        creationProvenance: .userCreated
    ))))

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Vault/Ideas.md", body: "duplicate"),
        MarkdownImportFile(path: "Vault/Nested/B.md", body: "second")
    ]))))
    let allNotes = try notes(from: runtime.query(.notes))
    let storedExisting = try note(from: runtime.query(.note(existing.id)))

    try expect(importResult.notes.map(\.title) == ["Ideas (2)", "B"], "folder Markdown Import should create flat Notes with title disambiguation")
    try expect(importResult.notes.map(\.body) == ["duplicate", "second"], "folder Markdown Import should preserve each raw Note Body")
    try expect(allNotes == [existing] + importResult.notes, "folder Markdown Import should not create user-facing folders or replace existing Notes")
    try expect(storedExisting == existing, "folder Markdown Import should leave existing Note content unchanged")
    try expect(importResult.provenance[importResult.notes[0].id] == ImportProvenance(sourcePath: "Vault/Ideas.md"), "folder Markdown Import should record source path provenance")
    try expect(importResult.provenance[importResult.notes[1].id] == ImportProvenance(sourcePath: "Vault/Nested/B.md"), "folder Markdown Import should record nested source path provenance without creating folders")
}

func importingMarkdownResolvesWikilinksMarkdownLinksAndUnresolvedWikilinkPlaceholders() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "A.md", body: """
        See [[B]].
        Read [B too](./B.md).
        Plan [[Future]].
        """),
        MarkdownImportFile(path: "B.md", body: "target")
    ]))))
    let source = importResult.notes[0]
    let target = importResult.notes[1]
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "Future" }) else {
        throw BehaviorTestFailure(description: "unresolved imported Wikilink should create a Placeholder Note")
    }
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(target.title == "B", "test setup should import target Note")
    try expect(placeholder.isPlaceholder, "unresolved imported Wikilink should create a Placeholder Note")
    try expect(placeholder.creationProvenance == .placeholderCreated, "unresolved imported Wikilink should record placeholder Creation Provenance")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "See [[B]]."),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "Read [B too](./B.md)."),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: placeholder.id, snippet: "Plan [[Future]].")
    ], "Markdown Import should resolve Wikilinks, Markdown links, and unresolved Wikilink placeholders")
}

func importingUnresolvedMarkdownLinkCreatesPlaceholderNoteAndExplicitLink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFile(.init(
        file: MarkdownImportFile(path: "A.md", body: "See [Future](Future.md).")
    ))))
    let source = importResult.notes[0]
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "Future" }) else {
        throw BehaviorTestFailure(description: "unresolved imported Markdown link should create a Placeholder Note")
    }
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(placeholder.isPlaceholder, "unresolved imported Markdown link should create a Placeholder Note")
    try expect(placeholder.creationProvenance == .placeholderCreated, "unresolved imported Markdown link should record placeholder Creation Provenance")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: placeholder.id, snippet: "See [Future](Future.md).")
    ], "unresolved imported Markdown link should create an Explicit Link to the Placeholder Note")
}

func importingFolderResolvesLinksToImportedNotesBeforeExistingLocalTitles() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let existing = try createdNote(from: runtime.execute(.createNote(.init(
        title: "B",
        body: "existing local note",
        creationProvenance: .userCreated
    ))))

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "A.md", body: """
        Read [B](B.md).
        See [[B]].
        """),
        MarkdownImportFile(path: "B.md", body: "imported note")
    ]))))
    let source = importResult.notes[0]
    let importedTarget = importResult.notes[1]
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(importedTarget.title == "B (2)", "imported target should be disambiguated against existing local title")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: importedTarget.id, snippet: "Read [B](B.md)."),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: importedTarget.id, snippet: "See [[B]].")
    ], "folder Markdown Import should resolve intra-import links to imported Notes before existing local titles")
    try expect(!links.contains { $0.targetNoteID == existing.id }, "folder Markdown Import should not point intra-import links at existing local title collisions")
}

func importingFolderResolvesRelativeMarkdownLinksByPathBeforeDuplicateBasenameTitles() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Vault/A.md", body: "Read [Nested B](Nested/B.md)."),
        MarkdownImportFile(path: "Vault/Nested/B.md", body: "nested target"),
        MarkdownImportFile(path: "Vault/B.md", body: "root target")
    ]))))
    let source = importResult.notes[0]
    let nestedTarget = importResult.notes[1]
    let rootTarget = importResult.notes[2]
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(nestedTarget.title == "B", "nested duplicate basename should keep first imported title")
    try expect(rootTarget.title == "B (2)", "root duplicate basename should be disambiguated")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: nestedTarget.id, snippet: "Read [Nested B](Nested/B.md).")
    ], "relative Markdown link should resolve by imported path before duplicate basename title")
}

func renamingImportedMarkdownLinkTargetDoesNotRewriteUnrelatedWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Source.md", body: "[Target](Target.md) [[Keep]]"),
        MarkdownImportFile(path: "Target.md", body: "target"),
        MarkdownImportFile(path: "Keep.md", body: "keep")
    ]))))
    let source = importResult.notes[0]
    let target = importResult.notes[1]
    let keep = importResult.notes[2]

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: target.id,
        title: "New Target"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Target](Target.md) [[Keep]]", "renaming an imported Markdown-link target should not rewrite an unrelated Wikilink token")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "[Target](Target.md) [[Keep]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: keep.id, snippet: "[Target](Target.md) [[Keep]]")
    ], "renaming an imported Markdown-link target should preserve unrelated Wikilink Explicit Links")
}

func renamingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRewriteUnrelatedWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sourceID = NoteID("source")
    let markdownID = NoteID("markdown")
    let wikiID = NoteID("wiki")
    let manifestOnlyID = NoteID("manifest-only")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Source.md", body: "[Markdown](Markdown.md) [[Wiki]]"),
            MarkdownImportFile(path: "Markdown.md", body: "markdown target"),
            MarkdownImportFile(path: "Wiki.md", body: "wiki target"),
            MarkdownImportFile(path: "ManifestOnly.md", body: "manifest-only target")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Source.md": sourceID,
                "Markdown.md": markdownID,
                "Wiki.md": wikiID,
                "ManifestOnly.md": manifestOnlyID
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: sourceID, targetNoteID: manifestOnlyID, snippet: "manifest-only edge")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let markdown = importResult.notes[1]
    let wiki = importResult.notes[2]
    let manifestOnly = importResult.notes[3]

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: markdown.id,
        title: "Renamed Markdown"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Markdown](Markdown.md) [[Wiki]]", "renaming an imported Markdown-link target should not rewrite a later Wikilink when manifest-only edges make link counts differ")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: markdown.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: wiki.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: manifestOnly.id, snippet: "manifest-only edge")
    ], "renaming an imported Markdown-link target should preserve body and manifest Explicit Links")
}

func renamingAndDeletingImportedManifestOnlyTargetDoesNotRewriteOrRemoveBodyWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sourceID = NoteID("source")
    let markdownID = NoteID("markdown")
    let wikiID = NoteID("wiki")
    let manifestOnlyID = NoteID("manifest-only")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Source.md", body: "[Markdown](Markdown.md) [[Wiki]]"),
            MarkdownImportFile(path: "Markdown.md", body: "markdown target"),
            MarkdownImportFile(path: "Wiki.md", body: "wiki target"),
            MarkdownImportFile(path: "ManifestOnly.md", body: "manifest-only target")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Source.md": sourceID,
                "Markdown.md": markdownID,
                "Wiki.md": wikiID,
                "ManifestOnly.md": manifestOnlyID
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: sourceID, targetNoteID: manifestOnlyID, snippet: "manifest-only edge")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let markdown = importResult.notes[1]
    let wiki = importResult.notes[2]
    let manifestOnly = importResult.notes[3]

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: manifestOnly.id,
        title: "Renamed Manifest Only"
    ))))
    let sourceAfterRename = try note(from: runtime.query(.note(source.id)))
    let linksAfterRename = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: manifestOnly.id))))
    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: manifestOnly.id,
        deletionConfirmation: .init(noteID: manifestOnly.id)
    ))))
    let sourceAfterDelete = try note(from: runtime.query(.note(source.id)))
    let linksAfterDelete = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(sourceAfterRename?.body == "[Markdown](Markdown.md) [[Wiki]]", "renaming a manifest-only target should not rewrite body Wikilinks")
    try expect(linksAfterRename == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: markdown.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: wiki.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: manifestOnly.id, snippet: "manifest-only edge")
    ], "renaming a manifest-only target should preserve body and manifest Explicit Links")
    try expect(sourceAfterDelete?.body == "[Markdown](Markdown.md) [[Wiki]]", "permanently deleting a manifest-only target should not remove body Wikilinks")
    try expect(linksAfterDelete == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: markdown.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: wiki.id, snippet: "[Markdown](Markdown.md) [[Wiki]]")
    ], "permanently deleting a manifest-only target should remove only the manifest Explicit Link")
}

func permanentlyDeletingImportedMarkdownLinkTargetDoesNotRemoveUnrelatedWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Source.md", body: "[Target](Target.md) [[Keep]]"),
        MarkdownImportFile(path: "Target.md", body: "target"),
        MarkdownImportFile(path: "Keep.md", body: "keep")
    ]))))
    let source = importResult.notes[0]
    let target = importResult.notes[1]
    let keep = importResult.notes[2]

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: target.id))))
    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: target.id,
        deletionConfirmation: .init(noteID: target.id)
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Target](Target.md) [[Keep]]", "permanently deleting an imported Markdown-link target should not remove an unrelated Wikilink token")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: keep.id, snippet: "[Target](Target.md) [[Keep]]")
    ], "permanently deleting an imported Markdown-link target should preserve unrelated Wikilink Explicit Links")
}

func permanentlyDeletingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRemoveUnrelatedWikilink() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sourceID = NoteID("source")
    let markdownID = NoteID("markdown")
    let wikiID = NoteID("wiki")
    let manifestOnlyID = NoteID("manifest-only")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Source.md", body: "[Markdown](Markdown.md) [[Wiki]]"),
            MarkdownImportFile(path: "Markdown.md", body: "markdown target"),
            MarkdownImportFile(path: "Wiki.md", body: "wiki target"),
            MarkdownImportFile(path: "ManifestOnly.md", body: "manifest-only target")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Source.md": sourceID,
                "Markdown.md": markdownID,
                "Wiki.md": wikiID,
                "ManifestOnly.md": manifestOnlyID
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: sourceID, targetNoteID: manifestOnlyID, snippet: "manifest-only edge")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let markdown = importResult.notes[1]
    let wiki = importResult.notes[2]
    let manifestOnly = importResult.notes[3]

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: markdown.id))))
    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: markdown.id,
        deletionConfirmation: .init(noteID: markdown.id)
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Markdown](Markdown.md) [[Wiki]]", "permanently deleting an imported Markdown-link target should not remove an unrelated Wikilink when manifest-only edges make link counts differ")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: wiki.id, snippet: "[Markdown](Markdown.md) [[Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: manifestOnly.id, snippet: "manifest-only edge")
    ], "permanently deleting an imported Markdown-link target should remove only that target edge and preserve unrelated body and manifest Explicit Links")
}

func renamingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Source.md", body: "[Keep](Keep.md) [[Target]]"),
        MarkdownImportFile(path: "Keep.md", body: "keep"),
        MarkdownImportFile(path: "Target.md", body: "target")
    ]))))
    let source = importResult.notes[0]
    let keep = importResult.notes[1]
    let target = importResult.notes[2]

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: target.id,
        title: "New Target"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Keep](Keep.md) [[New Target]]", "renaming an imported Wikilink target should rewrite only the Wikilink token")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: keep.id, snippet: "[Keep](Keep.md) [[New Target]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "[Keep](Keep.md) [[New Target]]")
    ], "renaming an imported Wikilink target should preserve unrelated Markdown-link Explicit Links")
}

func renamingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sourceID = NoteID("source")
    let markdownID = NoteID("markdown")
    let wikiID = NoteID("wiki")
    let manifestOnlyID = NoteID("manifest-only")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Source.md", body: "[Markdown](Markdown.md) [[Wiki]]"),
            MarkdownImportFile(path: "Markdown.md", body: "markdown target"),
            MarkdownImportFile(path: "Wiki.md", body: "wiki target"),
            MarkdownImportFile(path: "ManifestOnly.md", body: "manifest-only target")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Source.md": sourceID,
                "Markdown.md": markdownID,
                "Wiki.md": wikiID,
                "ManifestOnly.md": manifestOnlyID
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: sourceID, targetNoteID: manifestOnlyID, snippet: "manifest-only edge")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let markdown = importResult.notes[1]
    let wiki = importResult.notes[2]
    let manifestOnly = importResult.notes[3]

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: wiki.id,
        title: "Renamed Wiki"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Markdown](Markdown.md) [[Renamed Wiki]]", "renaming an imported Wikilink target should rewrite only that Wikilink token")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: markdown.id, snippet: "[Markdown](Markdown.md) [[Renamed Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: wiki.id, snippet: "[Markdown](Markdown.md) [[Renamed Wiki]]"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: manifestOnly.id, snippet: "manifest-only edge")
    ], "renaming an imported Wikilink target should preserve Markdown-link and manifest-only Explicit Links")
}

func permanentlyDeletingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge() throws {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })

    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFolder(.init(files: [
        MarkdownImportFile(path: "Source.md", body: "[Keep](Keep.md) [[Target]]"),
        MarkdownImportFile(path: "Keep.md", body: "keep"),
        MarkdownImportFile(path: "Target.md", body: "target")
    ]))))
    let source = importResult.notes[0]
    let keep = importResult.notes[1]
    let target = importResult.notes[2]
    now = Date(timeIntervalSince1970: 1_700_000_060)

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: target.id))))
    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: target.id,
        deletionConfirmation: .init(noteID: target.id)
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Keep](Keep.md)", "permanently deleting an imported Wikilink target should remove only the Wikilink token")
    try expect(storedSource?.lastEditedAt == source.lastEditedAt, "permanently deleting an imported Wikilink target should preserve source Last Edited Time")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: keep.id, snippet: "[Keep](Keep.md)")
    ], "permanently deleting an imported Wikilink target should preserve unrelated Markdown-link Explicit Links")
}

func permanentlyDeletingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges() throws {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    let sourceID = NoteID("source")
    let markdownID = NoteID("markdown")
    let wikiID = NoteID("wiki")
    let manifestOnlyID = NoteID("manifest-only")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Source.md", body: "[Markdown](Markdown.md) [[Wiki]]"),
            MarkdownImportFile(path: "Markdown.md", body: "markdown target"),
            MarkdownImportFile(path: "Wiki.md", body: "wiki target"),
            MarkdownImportFile(path: "ManifestOnly.md", body: "manifest-only target")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Source.md": sourceID,
                "Markdown.md": markdownID,
                "Wiki.md": wikiID,
                "ManifestOnly.md": manifestOnlyID
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: sourceID, targetNoteID: manifestOnlyID, snippet: "manifest-only edge")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let markdown = importResult.notes[1]
    let wiki = importResult.notes[2]
    let manifestOnly = importResult.notes[3]
    now = Date(timeIntervalSince1970: 1_700_000_060)

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: wiki.id))))
    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: wiki.id,
        deletionConfirmation: .init(noteID: wiki.id)
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.body == "[Markdown](Markdown.md)", "permanently deleting an imported Wikilink target should remove only that Wikilink token")
    try expect(storedSource?.lastEditedAt == source.lastEditedAt, "permanently deleting an imported Wikilink target with manifest-only edges should preserve source Last Edited Time")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: markdown.id, snippet: "[Markdown](Markdown.md)"),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: manifestOnly.id, snippet: "manifest-only edge")
    ], "permanently deleting an imported Wikilink target should preserve Markdown-link and manifest-only Explicit Links")
}

func importingExportBundlePreservesUnsupportedSyntaxAndAttachmentReferencesWithoutAttachmentSideEffects() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let body = """
    > [!note] unsupported callout stays raw
    ![[diagram.png]]
    ![diagram](diagram.png)
    """

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(files: [
        MarkdownImportFile(path: "Export/Raw.md", body: body)
    ])))))
    let imported = importResult.notes[0]
    let links = try explicitLinks(from: runtime.query(.explicitLinks(imported.id)))
    let activeNotes = try notes(from: runtime.query(.notes))

    try expect(imported.title == "Raw", "Export Bundle import should derive Note Title from bundled Markdown path")
    try expect(imported.body == body, "Export Bundle import should preserve unsupported syntax and attachment references exactly")
    try expect(imported.creationProvenance == .imported, "Export Bundle import should create imported Notes")
    try expect(importResult.provenance == [imported.id: ImportProvenance(sourcePath: "Export/Raw.md")], "Export Bundle import should retain source path provenance")
    try expect(links.isEmpty, "attachment references should not create Explicit Links")
    try expect(activeNotes == [imported], "attachment references should not create managed attachment Notes or Placeholder Notes")
}

func importingExportBundleUsesManifestToPreserveNoteIDsRelationshipsAndProvenance() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let exportedA = NoteID("exported-a")
    let exportedB = NoteID("exported-b")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Bundle/A.md", body: "A body"),
            MarkdownImportFile(path: "Bundle/B.md", body: "B body")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Bundle/A.md": exportedA,
                "Bundle/B.md": exportedB
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: exportedA, targetNoteID: exportedB, snippet: "manifest edge")
            ],
            acceptedRelationships: [
                AcceptedRelationship(sourceNoteID: exportedB, targetNoteID: exportedA)
            ],
            importProvenanceByPath: [
                "Bundle/A.md": ImportProvenance(sourcePath: "Original/A.md"),
                "Bundle/B.md": ImportProvenance(sourcePath: "Original/B.md")
            ]
        )
    )))))
    let importedA = importResult.notes[0]
    let importedB = importResult.notes[1]
    let links = try explicitLinks(from: runtime.query(.explicitLinks(importedA.id)))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(importedA.id == exportedA, "Export Bundle manifest should preserve Note IDs when available")
    try expect(importedB.id == exportedB, "Export Bundle manifest should preserve target Note ID")
    try expect(importedA.importProvenance == ImportProvenance(sourcePath: "Original/A.md"), "Export Bundle manifest should preserve imported Note provenance")
    try expect(importResult.provenance == [
        exportedA: ImportProvenance(sourcePath: "Original/A.md"),
        exportedB: ImportProvenance(sourcePath: "Original/B.md")
    ], "Export Bundle import result should summarize manifest provenance")
    try expect(links == [
        ExplicitLink(sourceNoteID: exportedA, targetNoteID: exportedB, snippet: "manifest edge")
    ], "Export Bundle manifest should restore app-specific Explicit Links")
    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: exportedA, targetNoteID: exportedB, provenance: .explicitLink),
        TrustedGraphEdge(sourceNoteID: exportedB, targetNoteID: exportedA, provenance: .acceptedRelationship)
    ], "Export Bundle manifest should restore app-specific Accepted Relationships")
}

func importingExportBundleDeduplicatesManifestExplicitLinksAlreadyPresentInBody() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let exportedA = NoteID("exported-a")
    let exportedB = NoteID("exported-b")

    let importResult = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Bundle/A.md", body: "See [[B]]."),
            MarkdownImportFile(path: "Bundle/B.md", body: "B body")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Bundle/A.md": exportedA,
                "Bundle/B.md": exportedB
            ],
            explicitLinks: [
                ExplicitLink(sourceNoteID: exportedA, targetNoteID: exportedB, snippet: "See [[B]].")
            ]
        )
    )))))
    let source = importResult.notes[0]
    let target = importResult.notes[1]
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "See [[B]].")
    ], "Export Bundle import should not duplicate matching body and manifest Explicit Links")
}

func markdownExportUsesFilesystemSafeFilenamesAndMapsThemToNoteIDs() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let first = try createdNote(from: runtime.execute(.createNote(.init(
        title: "My/Note?.md",
        body: "# Clean body",
        creationProvenance: .userCreated
    ))))
    let second = try createdNote(from: runtime.execute(.createNote(.init(
        title: "My:Note.md",
        body: "second",
        creationProvenance: .userCreated
    ))))

    let export = try markdownExport(from: runtime.query(.markdownExport(.init())))

    try expect(export.files == [
        MarkdownExportFile(path: "My-Note.md", body: "# Clean body"),
        MarkdownExportFile(path: "My-Note (2).md", body: "second")
    ], "Markdown Export should use deterministic filesystem-safe filenames and disambiguate collisions")
    try expect(export.manifest.noteIDsByPath == [
        "My-Note.md": first.id,
        "My-Note (2).md": second.id
    ], "Export Manifest should map exported filenames to stable Note IDs")
}

func markdownExportDisambiguatesCaseInsensitiveFilenameCollisions() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let first = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Readme",
        body: "upper",
        creationProvenance: .userCreated
    ))))
    let second = try createdNote(from: runtime.execute(.createNote(.init(
        title: "readme",
        body: "lower",
        creationProvenance: .userCreated
    ))))

    let export = try markdownExport(from: runtime.query(.markdownExport(.init())))

    try expect(export.files == [
        MarkdownExportFile(path: "Readme.md", body: "upper"),
        MarkdownExportFile(path: "readme (2).md", body: "lower")
    ], "Markdown Export should disambiguate filenames that collide case-insensitively")
    try expect(export.manifest.noteIDsByPath == [
        "Readme.md": first.id,
        "readme (2).md": second.id
    ], "Export Manifest should map case-insensitive-safe filenames to Note IDs")
}

func markdownExportStoresAcceptedRelationshipsInManifestOnly() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Source",
        body: "No accepted edge text here.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Target",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    let relationship = try acceptedRelationship(from: runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: source.id,
        targetNoteID: target.id
    ))))

    let export = try markdownExport(from: runtime.query(.markdownExport(.init())))

    try expect(export.files == [
        MarkdownExportFile(path: "Source.md", body: "No accepted edge text here."),
        MarkdownExportFile(path: "Target.md", body: "Target body.")
    ], "Accepted Relationships should not be inserted into exported Note Bodies")
    try expect(export.manifest.acceptedRelationships == [relationship], "Export Manifest should store Accepted Relationships outside Markdown content")
}

func exportBundleExcludesTrashByDefaultAndIncludesTrashWhenRequested() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let active = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Active",
        body: "active body",
        creationProvenance: .userCreated
    ))))
    let trashed = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Trashed",
        body: "trashed body",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: trashed.id))))

    let defaultBundle = try markdownExportBundle(from: runtime.query(.exportBundle(.init())))
    let bundleWithTrash = try markdownExportBundle(from: runtime.query(.exportBundle(.init(includeTrash: true))))

    try expect(defaultBundle.files == [
        MarkdownExportFile(path: "Active.md", body: "active body")
    ], "Export Bundle should export active Notes by default")
    try expect(defaultBundle.manifest.noteIDsByPath == [
        "Active.md": active.id
    ], "default Export Bundle manifest should map only active exported Notes")
    try expect(bundleWithTrash.files == [
        MarkdownExportFile(path: "Active.md", body: "active body"),
        MarkdownExportFile(path: "Trashed.md", body: "trashed body")
    ], "Export Bundle should include Trash only when requested")
    try expect(bundleWithTrash.manifest.noteIDsByPath == [
        "Active.md": active.id,
        "Trashed.md": trashed.id
    ], "Export Bundle manifest should map trashed Notes when included")
}

func exportBundleIncludesAISessionHistoryOnlyWhenRequested() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.answer(.init(prompt: "private prompt", mode: .general))
    let history = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    let defaultBundle = try markdownExportBundle(from: runtime.query(.exportBundle(.init())))
    let bundleWithHistory = try markdownExportBundle(from: runtime.query(.exportBundle(.init(includeAISessionHistory: true))))

    try expect(defaultBundle.aiSessionHistory.isEmpty, "Export Bundle should exclude AI Session History by default")
    try expect(defaultBundle.files.isEmpty && defaultBundle.manifest.noteIDsByPath.isEmpty, "Export Bundle should not include downloaded Local Model Profile files")
    try expect(bundleWithHistory.aiSessionHistory == history, "Export Bundle should include AI Session History only when requested")
}

func exportBundleIncludesEditProvenanceOnlyWhenRequested() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed(["AI-edited body."])))
    let sessionID = AISessionID("ai-session-1")
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Editable",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))
    let workflow = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(note.id)
    ))))
    guard case .directEdit(let operation) = workflow else {
        throw BehaviorTestFailure(description: "test setup should create a Direct Edit AI Operation")
    }

    let defaultBundle = try markdownExportBundle(from: runtime.query(.exportBundle(.init())))
    let bundleWithProvenance = try markdownExportBundle(from: runtime.query(.exportBundle(.init(includeEditProvenance: true))))

    try expect(defaultBundle.manifest.editProvenance.isEmpty, "Export Bundle should exclude Edit Provenance by default")
    try expect(bundleWithProvenance.manifest.editProvenance == [operation], "Export Bundle should include Edit Provenance in the manifest when requested")
}

func exportBundlePreservesImportProvenanceInManifest() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let importResult = try markdownImport(from: runtime.execute(.importMarkdownFile(.init(
        file: MarkdownImportFile(path: "Original/Imported.md", body: "imported body")
    ))))
    let imported = importResult.notes[0]

    let bundle = try markdownExportBundle(from: runtime.query(.exportBundle(.init())))

    try expect(bundle.files == [
        MarkdownExportFile(path: "Imported.md", body: "imported body")
    ], "Export Bundle should export imported Notes as Markdown")
    try expect(bundle.manifest.noteIDsByPath == [
        "Imported.md": imported.id
    ], "Export Bundle manifest should map imported filename to stable Note ID")
    try expect(bundle.manifest.importProvenanceByPath == [
        "Imported.md": ImportProvenance(sourcePath: "Original/Imported.md")
    ], "Export Bundle manifest should preserve Import Provenance outside Markdown content")
}

func exportBundlePreservesExplicitLinksInManifest() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let exportedA = NoteID("exported-a")
    let exportedB = NoteID("exported-b")
    let manifestLink = ExplicitLink(sourceNoteID: exportedA, targetNoteID: exportedB, snippet: "manifest edge")
    _ = try markdownImport(from: runtime.execute(.importExportBundle(.init(bundle: MarkdownExportBundle(
        files: [
            MarkdownImportFile(path: "Bundle/A.md", body: "A body"),
            MarkdownImportFile(path: "Bundle/B.md", body: "B body")
        ],
        manifest: MarkdownExportManifest(
            noteIDsByPath: [
                "Bundle/A.md": exportedA,
                "Bundle/B.md": exportedB
            ],
            explicitLinks: [manifestLink]
        )
    )))))

    let bundle = try markdownExportBundle(from: runtime.query(.exportBundle(.init())))

    try expect(bundle.manifest.explicitLinks == [manifestLink], "Export Bundle manifest should preserve Explicit Links outside Markdown content")
}

func markdownExportRendersExplicitLinksWithCurrentTargetTitles() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Old Title",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Source",
        body: "See [[Old Title]].",
        creationProvenance: .userCreated
    ))))
    let renamedTarget = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: target.id,
        title: "New Title"
    ))))

    let export = try markdownExport(from: runtime.query(.markdownExport(.init())))
    let storedSource = try note(from: runtime.query(.note(source.id)))

    try expect(storedSource?.body == "See [[New Title]].", "renaming a target should rewrite source Wikilink tokens")
    try expect(export.files == [
        MarkdownExportFile(path: "New Title.md", body: "Target body."),
        MarkdownExportFile(path: "Source.md", body: "See [[New Title]].")
    ], "Markdown Export should render Explicit Links with current target Note Titles")
    try expect(export.manifest.explicitLinks == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: renamedTarget.id, snippet: "See [[New Title]].")
    ], "Export Manifest should preserve the ID-backed Explicit Link")
}

func singleNoteShareReturnsCleanContentOnly() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed(["AI-edited clean body."])))
    let sessionID = AISessionID("ai-session-1")
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Share/Me?.md",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Target",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: note.id,
        targetNoteID: target.id
    )))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))
    _ = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(note.id)
    ))))

    let share = try singleNoteShare(from: runtime.query(.singleNoteShare(note.id)))

    try expect(share == SingleNoteShare(
        title: "Share/Me?.md",
        filename: "Share-Me.md",
        content: "AI-edited clean body."
    ), "Single-note Share should return only clean title, filename, and content")
    try expect(!share.content.contains("ai-operation") && !share.content.contains(target.id.rawValue), "Single-note Share content should not include Edit Provenance, relationship metadata, or collaboration state")
}

func renamingANoteThroughRuntimeCommandPreservesStableNoteID() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let createdNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Working title",
        body: "Body stays with the Note.",
        creationProvenance: .userCreated
    ))))

    let renamed = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: createdNote.id,
        title: "Settled title"
    ))))

    try expect(renamed.id == createdNote.id, "rename should preserve Note ID")
    try expect(renamed.title == "Settled title", "rename should apply the new Note Title")
    try expect(renamed.body == createdNote.body, "rename should preserve Note Body")
    try expect(renamed.creationProvenance == createdNote.creationProvenance, "rename should preserve Creation Provenance")

    switch try runtime.query(.note(createdNote.id)) {
    case .note(let note):
        try expect(note == renamed, "query by original Note ID should return renamed Note")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func renamingANoteRewritesSelfLinkingWikilinksByStableNoteID() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let selfLinked = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Old Title",
        body: "Self [[Old Title]].",
        creationProvenance: .userCreated
    ))))

    let renamed = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: selfLinked.id,
        title: "New Title"
    ))))
    let stored = try note(from: runtime.query(.note(selfLinked.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(selfLinked.id)))

    try expect(renamed.id == selfLinked.id, "self-link rename should preserve Note ID")
    try expect(stored?.body == "Self [[New Title]].", "rename should rewrite self-linking Wikilink tokens backed by the renamed Note ID")
    try expect(links == [
        ExplicitLink(sourceNoteID: selfLinked.id, targetNoteID: selfLinked.id, snippet: "Self [[New Title]].")
    ], "self-link rename should keep the Explicit Link self-targeting by stable Note ID")
}

func updatingANoteBodyThroughRuntimeCommandPreservesRawMarkdownAuthority() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let createdNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Markdown authority",
        body: "Initial",
        creationProvenance: .userCreated
    ))))

    let updatedBody = """
    # Heading

    - raw markdown
    - [[Wikilink]]

    ```swift
    let value = "*not parsed here*"
    ```
    """

    let updated = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
        noteID: createdNote.id,
        body: updatedBody
    ))))

    try expect(updated.id == createdNote.id, "body update should preserve Note ID")
    try expect(updated.title == createdNote.title, "body update should preserve Note Title")
    try expect(updated.creationProvenance == createdNote.creationProvenance, "body update should preserve Creation Provenance")
    try expect(updated.body == updatedBody, "body update should preserve raw Markdown exactly")

    switch try runtime.query(.note(createdNote.id)) {
    case .note(let note):
        try expect(note == updated, "query should return updated Note")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func listingNotesThroughRuntimeQueryReturnsCreatedNotes() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let first = try runtime.execute(.createNote(.init(
        title: "First",
        body: "One",
        creationProvenance: .userCreated
    )))
    let second = try runtime.execute(.createNote(.init(
        title: "Second",
        body: "Two",
        creationProvenance: .userCreated
    )))

    let firstNote = try createdNote(from: first)
    let secondNote = try createdNote(from: second)

    let queryResult = try runtime.query(.notes)

    switch queryResult {
    case .notes(let notes):
        try expect(notes == [firstNote, secondNote], "list query should return created Notes in creation order")
    default:
        throw BehaviorTestFailure(description: "expected a Note list query result")
    }
}

func creatingDuplicateNoteTitlesAppliesTitleDisambiguation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let first = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Project",
        body: "A",
        creationProvenance: .userCreated
    ))))
    let second = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Project",
        body: "B",
        creationProvenance: .userCreated
    ))))
    let third = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Project",
        body: "C",
        creationProvenance: .userCreated
    ))))

    try expect(first.title == "Project", "first Note should keep requested Note Title")
    try expect(second.title == "Project (2)", "second duplicate Note Title should be disambiguated")
    try expect(third.title == "Project (3)", "third duplicate Note Title should use next disambiguation suffix")
    try expect(Set([first.id, second.id, third.id]).count == 3, "disambiguated Notes should keep distinct Note IDs")
}

func renamingToDuplicateNoteTitleAppliesTitleDisambiguationWithoutChangingNoteID() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let existing = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Project",
        body: "Existing",
        creationProvenance: .userCreated
    ))))
    let renamedTarget = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Inbox",
        body: "Target",
        creationProvenance: .userCreated
    ))))

    let renamed = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: renamedTarget.id,
        title: "Project"
    ))))

    try expect(existing.title == "Project", "existing Note should keep its Note Title")
    try expect(renamed.id == renamedTarget.id, "disambiguated rename should preserve Note ID")
    try expect(renamed.title == "Project (2)", "duplicate rename should apply Title Disambiguation")

    switch try runtime.query(.notes) {
    case .notes(let notes):
        try expect(notes.map(\.title) == ["Project", "Project (2)"], "list query should expose unique disambiguated Note Titles")
    default:
        throw BehaviorTestFailure(description: "expected a Note list query result")
    }
}

func wikilinksInNoteBodyCreateExplicitLinksToExistingNoteIDs() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect this to [[Runtime Core]].",
        creationProvenance: .userCreated
    ))))

    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: "Connect this to [[Runtime Core]]."
        )
    ], "Wikilink should create an Explicit Link to the existing target Note ID")
}

func renamingANoteRewritesIncomingWikilinksByStableNoteID() throws {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Testing",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    let other = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Other",
        body: "Other body.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Source",
        body: "See [[Testing]] and [[Other]]. Testing as plain text.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let freshnessBeforeRename = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    now = Date(timeIntervalSince1970: 1_700_000_060)

    let renamed = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: target.id,
        title: "Hello"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let freshnessAfterRename = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(renamed.id == target.id, "rename should preserve the target Note ID")
    try expect(storedSource?.body == "See [[Hello]] and [[Other]]. Testing as plain text.", "rename should rewrite only Wikilink tokens backed by the renamed target Note ID")
    try expect(storedSource?.lastEditedAt == source.lastEditedAt, "rename-driven Wikilink rewrites should preserve source Last Edited Time")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "See [[Hello]] and [[Other]]. Testing as plain text."),
        ExplicitLink(sourceNoteID: source.id, targetNoteID: other.id, snippet: "See [[Hello]] and [[Other]]. Testing as plain text.")
    ], "rename-driven Wikilink rewrites should refresh Explicit Links without changing target Note IDs")
    try expect(operations.isEmpty, "rename-driven Wikilink rewrites should not create AI Operations")
    try expect(freshnessBeforeRename == .fresh, "Indexing Jobs should refresh User Search Derived Index before rename")
    try expect(freshnessAfterRename == .dirty, "rename-driven Wikilink rewrites should mark User Search Derived Index dirty")
}

func renamingANoteRewritesIncomingWikilinksInTrashedSourcesWithoutUserEditTimestamps() throws {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Target",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Source",
        body: "See [[Target]].",
        creationProvenance: .userCreated
    ))))
    let trashedSource = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: source.id)))).0
    now = Date(timeIntervalSince1970: 1_700_000_060)

    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: target.id,
        title: "Renamed Target"
    ))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(storedSource?.isTrashed == true, "rename should leave the source Note in Trash")
    try expect(storedSource?.body == "See [[Renamed Target]].", "rename should rewrite incoming Wikilink tokens in trashed source Notes")
    try expect(storedSource?.lastEditedAt == trashedSource.lastEditedAt, "rename-driven Wikilink rewrites in Trash should preserve source Last Edited Time")
    try expect(links == [
        ExplicitLink(sourceNoteID: source.id, targetNoteID: target.id, snippet: "See [[Renamed Target]].")
    ], "rename-driven Trash rewrites should refresh Explicit Links without changing target Note IDs")
}

func unresolvedWikilinksCreateVisiblePlaceholderNotesAndExplicitLinks() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Follow up with [[Missing Note]].",
        creationProvenance: .userCreated
    ))))

    let allNotes = try notes(from: runtime.query(.notes))
    guard let placeholder = allNotes.first(where: { $0.title == "Missing Note" }) else {
        throw BehaviorTestFailure(description: "unresolved Wikilink should create a visible Placeholder Note")
    }
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(placeholder.body == "", "Placeholder Note should have no user-authored body content")
    try expect(placeholder.creationProvenance == .placeholderCreated, "Placeholder Note should have placeholder Creation Provenance")
    try expect(placeholder.isPlaceholder, "Placeholder Note should be visible as a Placeholder Note")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: placeholder.id,
            snippet: "Follow up with [[Missing Note]]."
        )
    ], "unresolved Wikilink should create an Explicit Link to the Placeholder Note ID")
}

func addingBodyContentToPlaceholderNotePromotesItToNormalNote() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Follow up with [[Missing Note]].",
        creationProvenance: .userCreated
    ))))
    let placeholder = try notes(from: runtime.query(.notes)).first { $0.title == "Missing Note" }!

    let promoted = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
        noteID: placeholder.id,
        body: "This is now user-authored content."
    ))))

    try expect(promoted.id == placeholder.id, "promoted Placeholder Note should keep its Note ID")
    try expect(promoted.body == "This is now user-authored content.", "promoted Placeholder Note should store the authored body content")
    try expect(promoted.creationProvenance == .placeholderCreated, "promoted Placeholder Note should preserve original Creation Provenance")
    try expect(!promoted.isPlaceholder, "authored body content should promote the Placeholder Note to a normal Note")
}

func backlinksAreDerivedFromExplicitLinksWithSourceTitleAndSnippet() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: """
        Plain Runtime Core text should not count.
        Link line points at [[Runtime Core]] from here.
        """,
        creationProvenance: .userCreated
    ))))
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Plain Mention",
        body: "Runtime Core appears here without a Wikilink.",
        creationProvenance: .userCreated
    ))))

    let targetBacklinks = try backlinks(from: runtime.query(.backlinks(target.id)))

    try expect(targetBacklinks == [
        Backlink(
            sourceNoteID: source.id,
            sourceNoteTitle: "Daily Note",
            targetNoteID: target.id,
            snippet: "Link line points at [[Runtime Core]] from here."
        )
    ], "Backlinks should be derived only from Explicit Links and include source title plus snippet")
}

func repeatedWikilinksRemainMultipleExplicitLinkOccurrences() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: """
        First [[Runtime Core]] link.
        Second [[Runtime Core]] link.
        """,
        creationProvenance: .userCreated
    ))))

    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: "First [[Runtime Core]] link."
        ),
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: "Second [[Runtime Core]] link."
        )
    ], "repeated Wikilinks should remain multiple Explicit Link occurrences")
}

func trustedGraphIncludesExplicitLinksWithProvenance() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect this to [[Runtime Core]].",
        creationProvenance: .userCreated
    ))))

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.nodes == [
        TrustedGraphNode(noteID: target.id, title: "Runtime Core", isPlaceholder: false),
        TrustedGraphNode(noteID: source.id, title: "Daily Note", isPlaceholder: false)
    ], "Trusted Graph should expose active source and target Notes as nodes")
    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: target.id, provenance: .explicitLink)
    ], "Trusted Graph should expose Explicit Links with explicit-link provenance")
}

func sqliteBackedRuntimePersistsTrustedGraphEdgesAcrossRuntimeInstances() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let target = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect this to [[Runtime Core]] and [[Future Topic]].",
        creationProvenance: .userCreated
    ))))
    guard let placeholder = try notes(from: runtimeA.query(.notes)).first(where: { $0.title == "Future Topic" }) else {
        throw BehaviorTestFailure(description: "unresolved Wikilink should create a Placeholder Note")
    }
    _ = try runtimeA.execute(.createAcceptedRelationship(.init(
        sourceNoteID: target.id,
        targetNoteID: source.id
    )))

    let graphBeforeRelaunch = try trustedGraph(from: runtimeA.query(.trustedGraph))
    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let graphAfterRelaunch = try trustedGraph(from: runtimeB.query(.trustedGraph))

    try expect(graphBeforeRelaunch == TrustedGraph(
        nodes: [
            TrustedGraphNode(noteID: target.id, title: "Runtime Core", isPlaceholder: false),
            TrustedGraphNode(noteID: source.id, title: "Daily Note", isPlaceholder: false),
            TrustedGraphNode(noteID: placeholder.id, title: "Future Topic", isPlaceholder: true)
        ],
        edges: [
            TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: target.id, provenance: .explicitLink),
            TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: placeholder.id, provenance: .explicitLink),
            TrustedGraphEdge(sourceNoteID: target.id, targetNoteID: source.id, provenance: .acceptedRelationship)
        ]
    ), "test setup should create a mixed Trusted Graph before relaunch")
    try expect(graphAfterRelaunch == graphBeforeRelaunch, "SQLite-backed runtime should preserve Trusted Graph edges across runtime instances")
}

func sqliteBackedRuntimeBackfillsTrustedGraphEdgesFromStoredNoteBodies() throws {
    let storageURL = temporarySQLiteStorageURL()
    defer { try? FileManager.default.removeItem(at: storageURL) }
    let runtimeA = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let target = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtimeA.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect this to [[Runtime Core]] and [[Future Topic]].",
        creationProvenance: .userCreated
    ))))
    guard let placeholder = try notes(from: runtimeA.query(.notes)).first(where: { $0.title == "Future Topic" }) else {
        throw BehaviorTestFailure(description: "unresolved Wikilink should create a Placeholder Note")
    }
    try executeSQLite("DELETE FROM explicit_links", storageURL: storageURL)
    try executeSQLite("DELETE FROM accepted_relationships", storageURL: storageURL)

    let runtimeB = try RuntimeCoreHarness.makeSQLiteBacked(storageURL: storageURL)
    let graphAfterMigration = try trustedGraph(from: runtimeB.query(.trustedGraph))

    try expect(graphAfterMigration == TrustedGraph(
        nodes: [
            TrustedGraphNode(noteID: target.id, title: "Runtime Core", isPlaceholder: false),
            TrustedGraphNode(noteID: source.id, title: "Daily Note", isPlaceholder: false),
            TrustedGraphNode(noteID: placeholder.id, title: "Future Topic", isPlaceholder: true)
        ],
        edges: [
            TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: target.id, provenance: .explicitLink),
            TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: placeholder.id, provenance: .explicitLink)
        ]
    ), "SQLite-backed runtime should backfill persisted Explicit Links from stored Wikilinks when graph rows are missing")
}

func trustedGraphMarksPlaceholderNodesFromUnresolvedWikilinks() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Plan for [[Future Topic]].",
        creationProvenance: .userCreated
    ))))
    let placeholder = try notes(from: runtime.query(.notes)).first { $0.title == "Future Topic" }!

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.nodes == [
        TrustedGraphNode(noteID: source.id, title: "Daily Note", isPlaceholder: false),
        TrustedGraphNode(noteID: placeholder.id, title: "Future Topic", isPlaceholder: true)
    ], "Trusted Graph should include Placeholder Notes and mark them as placeholders")
    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: placeholder.id, provenance: .explicitLink)
    ], "Trusted Graph should include Explicit Links to Placeholder Notes")
}

func presentationTrustedGraphMapsRuntimeMembershipAndPlaceholderKind() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Plan for [[Future Topic]].",
        creationProvenance: .userCreated
    ))))
    let placeholder = try notes(from: runtime.query(.notes)).first { $0.title == "Future Topic" }!
    let sourceAppID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let placeholderAppID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    let presentation = try PresentationTrustedGraph(runtimeGraph: trustedGraph(from: runtime.query(.trustedGraph))) { noteID in
        switch noteID {
        case source.id: sourceAppID
        case placeholder.id: placeholderAppID
        default: throw BehaviorTestFailure(description: "unexpected Note ID in Trusted Graph mapping")
        }
    }

    try expect(presentation.nodes == [
        PresentationTrustedGraphNode(
            id: sourceAppID,
            runtimeNoteID: source.id,
            title: "Daily Note",
            kind: .note
        ),
        PresentationTrustedGraphNode(
            id: placeholderAppID,
            runtimeNoteID: placeholder.id,
            title: "Future Topic",
            kind: .placeholderNote
        )
    ], "presentation Trusted Graph should map runtime graph membership and preserve Placeholder distinction")
    try expect(presentation.edges == [
        PresentationTrustedGraphEdge(
            sourceID: sourceAppID,
            targetID: placeholderAppID,
            provenance: .explicitLink
        )
    ], "presentation Trusted Graph should map runtime Trusted Graph edges by app IDs")
}

func presentationTrustedGraphOpenIntentDistinguishesPlaceholderPromotion() throws {
    let normalID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let placeholderID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    let graph = PresentationTrustedGraph(
        nodes: [
            PresentationTrustedGraphNode(
                id: normalID,
                runtimeNoteID: NoteID("normal-note"),
                title: "Daily Note",
                kind: .note
            ),
            PresentationTrustedGraphNode(
                id: placeholderID,
                runtimeNoteID: NoteID("placeholder-note"),
                title: "Future Topic",
                kind: .placeholderNote
            )
        ],
        edges: []
    )

    try expect(
        graph.openIntent(for: normalID) == .openExistingNote(normalID),
        "normal Trusted Graph nodes should open the existing Note editor route"
    )
    try expect(
        graph.openIntent(for: placeholderID) == .openPlaceholderForPromotion(placeholderID),
        "Placeholder Trusted Graph nodes should open the existing editor in placeholder-promotion mode"
    )
    try expect(
        graph.openIntent(for: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!) == nil,
        "missing Trusted Graph nodes should not produce an open intent"
    )
}

func trustedGraphDeduplicatesRepeatedExplicitLinkEdges() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: """
        First [[Runtime Core]] link.
        Second [[Runtime Core]] link.
        """,
        creationProvenance: .userCreated
    ))))

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: target.id, provenance: .explicitLink)
    ], "Trusted Graph should collapse repeated Explicit Link occurrences into one edge")
}

func trustedGraphExcludesTrashedNotesAndEdgesInvolvingThem() throws {
    let sourceTrashRuntime = RuntimeCoreHarness.makeInMemory()
    let sourceTrashTarget = try createdNote(from: sourceTrashRuntime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let trashedSource = try createdNote(from: sourceTrashRuntime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect to [[Runtime Core]].",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: sourceTrashRuntime.execute(.moveNoteToTrash(.init(noteID: trashedSource.id))))

    let sourceTrashGraph = try trustedGraph(from: sourceTrashRuntime.query(.trustedGraph))

    try expect(sourceTrashGraph.nodes == [
        TrustedGraphNode(noteID: sourceTrashTarget.id, title: "Runtime Core", isPlaceholder: false)
    ], "Trusted Graph should exclude trashed source Notes")
    try expect(sourceTrashGraph.edges.isEmpty, "Trusted Graph should exclude edges from trashed source Notes")

    let targetTrashRuntime = RuntimeCoreHarness.makeInMemory()
    let trashedTarget = try createdNote(from: targetTrashRuntime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let activeSource = try createdNote(from: targetTrashRuntime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect to [[Runtime Core]].",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: targetTrashRuntime.execute(.moveNoteToTrash(.init(noteID: trashedTarget.id))))

    let targetTrashGraph = try trustedGraph(from: targetTrashRuntime.query(.trustedGraph))

    try expect(targetTrashGraph.nodes == [
        TrustedGraphNode(noteID: activeSource.id, title: "Daily Note", isPlaceholder: false)
    ], "Trusted Graph should exclude trashed target Notes")
    try expect(targetTrashGraph.edges.isEmpty, "Trusted Graph should exclude edges involving trashed target Notes")
}

func trustedGraphIncludesUserCreatedAcceptedRelationshipsWithoutChangingNoteBodies() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "No wikilink here.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: source.id,
        targetNoteID: target.id
    )))

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: source.id, targetNoteID: target.id, provenance: .acceptedRelationship)
    ], "Trusted Graph should include Accepted Relationships with accepted-relationship provenance")

    switch try runtime.query(.note(source.id)) {
    case .note(let note):
        try expect(note?.body == "No wikilink here.", "Accepted Relationships should not be inserted into source Note Body")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    switch try runtime.query(.note(target.id)) {
    case .note(let note):
        try expect(note?.body == "Target body.", "Accepted Relationships should not be inserted into target Note Body")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func aiCannotCreateAcceptedRelationships() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Source body.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.createAcceptedRelationship(.init(
            sourceNoteID: source.id,
            targetNoteID: target.id
        )), source: .ai)
    }

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.edges.isEmpty, "AI-rejected Accepted Relationship command should leave Trusted Graph unchanged")
}

func trustedGraphExcludesAcceptedRelationshipEdgesInvolvingTrash() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Source body.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: source.id,
        targetNoteID: target.id
    )))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: target.id))))

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.nodes == [
        TrustedGraphNode(noteID: source.id, title: "Daily Note", isPlaceholder: false)
    ], "Trusted Graph should exclude trashed Accepted Relationship targets")
    try expect(graph.edges.isEmpty, "Trusted Graph should exclude Accepted Relationship edges involving Trash")
}

func relationshipScanReturnsSuggestedRelationshipsWithoutChangingTrustedGraph() throws {
    let source = NoteID("note-1")
    let target = NoteID("note-2")
    let citation = SourceCitation(noteID: source, noteFragmentID: "source-fragment")
    let suggestion = SuggestedRelationship(
        sourceNoteID: source,
        targetNoteID: target,
        explanation: "Both notes describe runtime graph review.",
        citations: [citation]
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(suggestions: [suggestion]))
    let sourceNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Source body.",
        creationProvenance: .userCreated
    ))))
    let targetNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let suggestions = try suggestedRelationships(from: runtime.execute(.runRelationshipScan(.init(noteID: sourceNote.id))))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(sourceNote.id == source, "test setup should keep deterministic source Note ID")
    try expect(targetNote.id == target, "test setup should keep deterministic target Note ID")
    try expect(suggestions == [suggestion], "Relationship Scan should return adapter Suggested Relationships with explanation and Source Citations")
    try expect(graph.edges.isEmpty, "Suggested Relationships should not appear in the default Trusted Graph before acceptance")
}

func relationshipScanFailsFastWithoutUsableLocalModelProfile() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(suggestions: [
        SuggestedRelationship(
            sourceNoteID: .init("note-1"),
            targetNoteID: .init("note-2"),
            explanation: "Should not be reached without a usable model.",
            citations: []
        )
    ]))
    let sourceNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Source body.",
        creationProvenance: .userCreated
    ))))
    let graphBefore = try trustedGraph(from: runtime.query(.trustedGraph))

    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.execute(.runRelationshipScan(.init(noteID: sourceNote.id)))
    }

    let graphAfter = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graphAfter == graphBefore, "Relationship Scan should leave Trusted Graph unchanged when AI is unavailable")
}

func frontendRelationshipScanPolicyKeepsSuggestionsOutOfTrustedGraphPresentationUntilPromotion() throws {
    let source = NoteID("note-1")
    let target = NoteID("note-2")
    let suggestion = SuggestedRelationship(
        sourceNoteID: source,
        targetNoteID: target,
        explanation: "Both notes describe runtime graph review.",
        citations: [SourceCitation(noteID: source, noteFragmentID: "source-fragment")]
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(suggestions: [suggestion]))
    let sourceNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "No wikilink here.",
        creationProvenance: .userCreated
    ))))
    let targetNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    let sourceAppID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    let targetAppID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

    let suggestions = try suggestedRelationships(from: runtime.execute(.runRelationshipScan(.init(noteID: sourceNote.id))))
    let presentation = try PresentationTrustedGraph(runtimeGraph: trustedGraph(from: runtime.query(.trustedGraph))) { noteID in
        switch noteID {
        case sourceNote.id: sourceAppID
        case targetNote.id: targetAppID
        default: throw BehaviorTestFailure(description: "unexpected Note ID in Trusted Graph mapping")
        }
    }
    let policy = PresentationTrustedGraphRelationshipScanPolicy.firstFrontendIntegration

    try expect(sourceNote.id == source, "test setup should keep deterministic source Note ID")
    try expect(targetNote.id == target, "test setup should keep deterministic target Note ID")
    try expect(suggestions == [suggestion], "Relationship Scan should return Suggested Relationships for a separate future review surface")
    try expect(presentation.edges.isEmpty, "presentation Trusted Graph should not expose unaccepted Suggested Relationships as trusted edges")
    try expect(policy.reviewUI == .deferredFromFirstFrontendIntegration, "Relationship Scan review UI should be explicitly deferred from first frontend integration")
    try expect(policy.graphInteractions == .navigationOnly, "first frontend graph interactions should stay navigation-only")
    try expect(policy.trustedGraphProvenances == [.explicitLink, .acceptedRelationship], "Trusted Graph presentation should expose only Explicit Links and Accepted Relationships as edge provenances")
    try expect(policy.shouldRenderInTrustedGraph(suggestion) == false, "unaccepted Suggested Relationships should stay out of the visual Trusted Graph")
    try expect(policy.promotion == .runtimePromotionCommandCreatesAcceptedRelationship, "future review UI should promote suggestions through the runtime into Accepted Relationships")
    try expect(
        policy.promotionCommand(for: suggestion) == .promoteSuggestedRelationship(.init(suggestedRelationship: suggestion)),
        "future review UI should promote Suggested Relationships through the suggestion-specific runtime command"
    )
}

func relationshipScanRejectsPlaceholderNotesWithoutChangingGraph() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Follow up with [[Missing Note]].",
        creationProvenance: .userCreated
    ))))
    let placeholder = try notes(from: runtime.query(.notes)).first { $0.title == "Missing Note" }!
    let graphBefore = try trustedGraph(from: runtime.query(.trustedGraph))

    try expectRuntimeError(.relationshipScanRequiresNonPlaceholderNote(placeholder.id)) {
        _ = try runtime.execute(.runRelationshipScan(.init(noteID: placeholder.id)))
    }

    let graphAfter = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graphAfter == graphBefore, "rejected Placeholder Note scan should leave Trusted Graph unchanged")
}

func relationshipScanRejectsNotesInTrashWithoutChangingGraph() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Archived Lead",
        body: "This should not be scanned from Trash.",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: note.id))))
    let graphBefore = try trustedGraph(from: runtime.query(.trustedGraph))

    try expectRuntimeError(.relationshipScanRequiresActiveNote(note.id)) {
        _ = try runtime.execute(.runRelationshipScan(.init(noteID: note.id)))
    }

    let graphAfter = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graphAfter == graphBefore, "rejected Trash scan should leave Trusted Graph unchanged")
}

func userPromotionConvertsSuggestionIntoAcceptedRelationshipWithoutExplicitLink() throws {
    let source = NoteID("note-1")
    let target = NoteID("note-2")
    let suggestion = SuggestedRelationship(
        sourceNoteID: source,
        targetNoteID: target,
        explanation: "Both notes describe runtime graph review.",
        citations: [SourceCitation(noteID: source, noteFragmentID: "source-fragment")]
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(suggestions: [suggestion]))
    let sourceNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "No wikilink here.",
        creationProvenance: .userCreated
    ))))
    let targetNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    let suggestions = try suggestedRelationships(from: runtime.execute(.runRelationshipScan(.init(noteID: sourceNote.id))))

    let accepted = try acceptedRelationship(from: runtime.execute(.promoteSuggestedRelationship(.init(suggestedRelationship: suggestions[0]))))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(sourceNote.id)))

    try expect(accepted == AcceptedRelationship(sourceNoteID: sourceNote.id, targetNoteID: targetNote.id), "promotion should create an Accepted Relationship from the Suggested Relationship")
    try expect(graph.edges == [
        TrustedGraphEdge(sourceNoteID: sourceNote.id, targetNoteID: targetNote.id, provenance: .acceptedRelationship)
    ], "promoted Suggested Relationship should appear in Trusted Graph as an Accepted Relationship")
    try expect(links.isEmpty, "promoted Suggested Relationship should not create an Explicit Link")
}

func aiCannotPromoteSuggestedRelationships() throws {
    let source = NoteID("note-1")
    let target = NoteID("note-2")
    let suggestion = SuggestedRelationship(
        sourceNoteID: source,
        targetNoteID: target,
        explanation: "Both notes describe runtime graph review.",
        citations: [SourceCitation(noteID: source, noteFragmentID: "source-fragment")]
    )
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "No wikilink here.",
        creationProvenance: .userCreated
    ))))
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.promoteSuggestedRelationship(.init(suggestedRelationship: suggestion)), source: .ai)
    }

    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(graph.edges.isEmpty, "AI-rejected Suggested Relationship promotion should leave Trusted Graph unchanged")
}

func embedReferencesRemainRawContentWithoutExplicitLinks() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let body = """
    Image stays raw: ![[diagram.png]]
    Real link: [[Runtime Core]]
    """
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: body,
        creationProvenance: .userCreated
    ))))

    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let allNotes = try notes(from: runtime.query(.notes))

    try expect(source.body == body, "embed reference should remain raw Note Body content")
    try expect(!allNotes.contains { $0.title == "diagram.png" }, "embed reference should not create a Placeholder Note")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: "Real link: [[Runtime Core]]"
        )
    ], "embed reference should not create an Explicit Link")
}

func movingANoteToTrashPreservesContentExplicitLinksAndProvenance() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect to [[Runtime Core]].",
        creationProvenance: .imported
    ))))
    let linksBeforeTrash = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    let (trashed, undo) = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: source.id))))
    let linksAfterTrash = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let activeNotes = try notes(from: runtime.query(.notes))

    try expect(trashed.id == source.id, "moving to Trash should preserve Note ID")
    try expect(trashed.title == source.title, "moving to Trash should preserve Note Title")
    try expect(trashed.body == source.body, "moving to Trash should preserve Note Body")
    try expect(trashed.creationProvenance == source.creationProvenance, "moving to Trash should preserve Creation Provenance")
    try expect(trashed.isTrashed, "moving to Trash should mark the Note as trashed")
    try expect(undo.noteID == source.id, "moving to Trash should create a Trash Undo opportunity")
    try expect(linksAfterTrash == linksBeforeTrash, "moving to Trash should preserve Explicit Links")
    try expect(activeNotes == [target], "default Notes query should exclude Notes in Trash")
}

func movingWikilinkTargetToTrashPreservesIncomingSourceWikilinks() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect to [[Runtime Core]].",
        creationProvenance: .userCreated
    ))))
    let linksBeforeTrash = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: target.id))))
    let storedSource = try note(from: runtime.query(.note(source.id)))
    let linksAfterTrash = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    try expect(storedSource?.body == "Connect to [[Runtime Core]].", "moving a Wikilink target to Trash should preserve incoming source Wikilink tokens")
    try expect(storedSource?.lastEditedAt == source.lastEditedAt, "moving a Wikilink target to Trash should not change source Last Edited Time")
    try expect(linksAfterTrash == linksBeforeTrash, "moving a Wikilink target to Trash should preserve incoming Explicit Links")
    try expect(!graph.edges.contains { $0.targetNoteID == target.id }, "Trusted Graph should exclude active edges to a Wikilink target in Trash")
}

func trashUndoRestoresTheNoteToActiveState() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Undo target",
        body: "Keep this body.",
        creationProvenance: .imported
    ))))
    let (_, undo) = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: created.id))))

    let restored = try restoredNote(from: runtime.execute(.undoTrash(.init(opportunity: undo))))
    let activeNotes = try notes(from: runtime.query(.notes))

    try expect(restored.id == created.id, "Trash Undo should preserve Note ID")
    try expect(restored.body == created.body, "Trash Undo should preserve Note Body")
    try expect(restored.creationProvenance == created.creationProvenance, "Trash Undo should preserve Creation Provenance")
    try expect(!restored.isTrashed, "Trash Undo should restore the Note to active state")
    try expect(activeNotes == [restored], "default Notes query should include the restored Note")
}

func explicitRestoreFromTrashPreservesContentExplicitLinksBacklinksAndProvenance() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Runtime Core",
        body: "Target body",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Connect to [[Runtime Core]].",
        creationProvenance: .imported
    ))))
    let linksBeforeTrash = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let backlinksBeforeTrash = try backlinks(from: runtime.query(.backlinks(target.id)))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: source.id))))

    let restored = try restoredNote(from: runtime.execute(.restoreNoteFromTrash(.init(noteID: source.id))))
    let linksAfterRestore = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let backlinksAfterRestore = try backlinks(from: runtime.query(.backlinks(target.id)))
    let activeNotes = try notes(from: runtime.query(.notes))

    try expect(restored.id == source.id, "explicit restore should preserve Note ID")
    try expect(restored.body == source.body, "explicit restore should preserve Note Body")
    try expect(restored.creationProvenance == source.creationProvenance, "explicit restore should preserve Creation Provenance")
    try expect(!restored.isTrashed, "explicit restore should restore the Note to active state")
    try expect(linksAfterRestore == linksBeforeTrash, "explicit restore should preserve Explicit Links")
    try expect(backlinksAfterRestore == backlinksBeforeTrash, "explicit restore should preserve Backlinks")
    try expect(activeNotes == [target, restored], "default Notes query should include explicitly restored Notes")
}

func permanentDeleteRequiresTrashedNoteAndDeletionConfirmation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Delete target",
        body: "Remove permanently only after Trash.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.noteNotInTrash(created.id)) {
        _ = try runtime.execute(.permanentlyDeleteNote(.init(
            noteID: created.id,
            deletionConfirmation: .init(noteID: created.id)
        )))
    }

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: created.id))))

    try expectRuntimeError(.deletionConfirmationRequired(created.id)) {
        _ = try runtime.execute(.permanentlyDeleteNote(.init(
            noteID: created.id,
            deletionConfirmation: nil
        )))
    }

    let deletedNoteID = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: created.id,
        deletionConfirmation: .init(noteID: created.id)
    ))))
    let activeNotes = try notes(from: runtime.query(.notes))

    try expect(deletedNoteID == created.id, "permanent delete should return the deleted Note ID")
    try expect(activeNotes.isEmpty, "permanently deleted Notes should not appear in default Notes query")

    switch try runtime.query(.note(created.id)) {
    case .note(let note):
        try expect(note == nil, "permanently deleted Note should no longer be readable")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func permanentlyDeletingANoteRemovesIncomingWikilinksWithoutUserEditTimestamps() throws {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Delete Target",
        body: "Target body.",
        creationProvenance: .userCreated
    ))))
    let kept = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Keep Target",
        body: "Kept body.",
        creationProvenance: .userCreated
    ))))
    let punctuationSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Punctuation Source",
        body: "See [[Delete Target]].",
        creationProvenance: .userCreated
    ))))
    let proseSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Prose Source",
        body: "Before [[Delete Target]] after.",
        creationProvenance: .userCreated
    ))))
    let onlyLinkSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Only Link Source",
        body: "[[Delete Target]]",
        creationProvenance: .userCreated
    ))))
    let repeatedOnlyLinkSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Repeated Only Link Source",
        body: "[[Delete Target]] [[Delete Target]]",
        creationProvenance: .userCreated
    ))))
    let repeatedPunctuationSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Repeated Punctuation Source",
        body: "See [[Delete Target]] [[Delete Target]].",
        creationProvenance: .userCreated
    ))))
    let repeatedProseSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Repeated Prose Source",
        body: "Before [[Delete Target]] [[Delete Target]] after.",
        creationProvenance: .userCreated
    ))))
    let mixedSource = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Mixed Source",
        body: "Keep [[Keep Target]] and remove [[Delete Target]].",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: target.id))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let freshnessBeforeDelete = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    now = Date(timeIntervalSince1970: 1_700_000_060)

    _ = try permanentlyDeletedNoteID(from: runtime.execute(.permanentlyDeleteNote(.init(
        noteID: target.id,
        deletionConfirmation: .init(noteID: target.id)
    ))))
    let storedPunctuationSource = try note(from: runtime.query(.note(punctuationSource.id)))
    let storedProseSource = try note(from: runtime.query(.note(proseSource.id)))
    let storedOnlyLinkSource = try note(from: runtime.query(.note(onlyLinkSource.id)))
    let storedRepeatedOnlyLinkSource = try note(from: runtime.query(.note(repeatedOnlyLinkSource.id)))
    let storedRepeatedPunctuationSource = try note(from: runtime.query(.note(repeatedPunctuationSource.id)))
    let storedRepeatedProseSource = try note(from: runtime.query(.note(repeatedProseSource.id)))
    let storedMixedSource = try note(from: runtime.query(.note(mixedSource.id)))
    let punctuationLinks = try explicitLinks(from: runtime.query(.explicitLinks(punctuationSource.id)))
    let proseLinks = try explicitLinks(from: runtime.query(.explicitLinks(proseSource.id)))
    let onlyLinkLinks = try explicitLinks(from: runtime.query(.explicitLinks(onlyLinkSource.id)))
    let repeatedOnlyLinkLinks = try explicitLinks(from: runtime.query(.explicitLinks(repeatedOnlyLinkSource.id)))
    let repeatedPunctuationLinks = try explicitLinks(from: runtime.query(.explicitLinks(repeatedPunctuationSource.id)))
    let repeatedProseLinks = try explicitLinks(from: runtime.query(.explicitLinks(repeatedProseSource.id)))
    let mixedLinks = try explicitLinks(from: runtime.query(.explicitLinks(mixedSource.id)))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))
    let freshnessAfterDelete = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let targetSearchResults = try userSearchResults(from: runtime.query(.userSearch("Delete Target")))

    try expect(storedPunctuationSource?.body == "See.", "permanent delete should remove incoming Wikilink tokens and extra space before punctuation")
    try expect(storedProseSource?.body == "Before after.", "permanent delete should mechanically close prose around a removed Wikilink")
    try expect(storedOnlyLinkSource?.body == "", "permanent delete should leave an empty body when the only content was the incoming Wikilink")
    try expect(storedRepeatedOnlyLinkSource?.body == "", "permanent delete should remove adjacent repeated whole-body incoming Wikilink tokens")
    try expect(storedRepeatedPunctuationSource?.body == "See.", "permanent delete should remove adjacent repeated incoming Wikilink tokens before punctuation")
    try expect(storedRepeatedProseSource?.body == "Before after.", "permanent delete should remove adjacent repeated incoming Wikilink tokens in prose")
    try expect(storedMixedSource?.body == "Keep [[Keep Target]] and remove.", "permanent delete should preserve unrelated Wikilinks")
    try expect(storedPunctuationSource?.lastEditedAt == punctuationSource.lastEditedAt, "permanent-delete Wikilink cleanup should preserve source Last Edited Time")
    try expect(storedProseSource?.lastEditedAt == proseSource.lastEditedAt, "permanent-delete prose cleanup should preserve source Last Edited Time")
    try expect(storedOnlyLinkSource?.lastEditedAt == onlyLinkSource.lastEditedAt, "permanent-delete whole-body cleanup should preserve source Last Edited Time")
    try expect(storedRepeatedOnlyLinkSource?.lastEditedAt == repeatedOnlyLinkSource.lastEditedAt, "permanent-delete repeated whole-body cleanup should preserve source Last Edited Time")
    try expect(storedRepeatedPunctuationSource?.lastEditedAt == repeatedPunctuationSource.lastEditedAt, "permanent-delete repeated punctuation cleanup should preserve source Last Edited Time")
    try expect(storedRepeatedProseSource?.lastEditedAt == repeatedProseSource.lastEditedAt, "permanent-delete repeated prose cleanup should preserve source Last Edited Time")
    try expect(storedMixedSource?.lastEditedAt == mixedSource.lastEditedAt, "permanent-delete mixed cleanup should preserve source Last Edited Time")
    try expect(punctuationLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned punctuation source")
    try expect(proseLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned prose source")
    try expect(onlyLinkLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned whole-link source")
    try expect(repeatedOnlyLinkLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned repeated whole-link source")
    try expect(repeatedPunctuationLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned repeated punctuation source")
    try expect(repeatedProseLinks.isEmpty, "permanent delete should refresh Explicit Links for cleaned repeated prose source")
    try expect(mixedLinks == [
        ExplicitLink(sourceNoteID: mixedSource.id, targetNoteID: kept.id, snippet: "Keep [[Keep Target]] and remove.")
    ], "permanent delete should keep unrelated Explicit Links after cleanup")
    try expect(!graph.nodes.contains { $0.noteID == target.id }, "Trusted Graph should not include permanently deleted target node")
    try expect(!graph.edges.contains { $0.sourceNoteID == target.id || $0.targetNoteID == target.id }, "Trusted Graph should not include edges involving permanently deleted target")
    try expect(freshnessBeforeDelete == .fresh, "Indexing Jobs should refresh User Search Derived Index before permanent delete")
    try expect(freshnessAfterDelete == .dirty, "permanent-delete Wikilink cleanup should mark User Search Derived Index dirty")
    try expect(targetSearchResults.isEmpty, "refreshed User Search should not retain removed incoming Wikilink text")
}

func aiFacingRuntimeCommandsCannotMoveNotesToTrashOrPermanentlyDeleteNotes() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let active = try createdNote(from: runtime.execute(.createNote(.init(
        title: "AI protected active",
        body: "AI cannot trash this.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.moveNoteToTrash(.init(noteID: active.id)), source: .ai)
    }

    let activeNotesAfterRejectedTrash = try notes(from: runtime.query(.notes))
    try expect(activeNotesAfterRejectedTrash == [active], "AI-rejected move to Trash should leave the Note active")

    let trashedTarget = try createdNote(from: runtime.execute(.createNote(.init(
        title: "AI protected trashed",
        body: "AI cannot permanently delete this.",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: trashedTarget.id))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.permanentlyDeleteNote(.init(
            noteID: trashedTarget.id,
            deletionConfirmation: .init(noteID: trashedTarget.id)
        )), source: .ai)
    }

    switch try runtime.query(.note(trashedTarget.id)) {
    case .note(let note):
        try expect(note?.isTrashed == true, "AI-rejected permanent delete should leave the trashed Note recoverable")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }
}

func aiCannotUndoTrash() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Undo protected",
        body: "AI cannot resurrect this.",
        creationProvenance: .userCreated
    ))))
    let (_, undo) = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: created.id))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.undoTrash(.init(opportunity: undo)), source: .ai)
    }

    let activeNotes = try notes(from: runtime.query(.notes))

    switch try runtime.query(.note(created.id)) {
    case .note(let note):
        try expect(note?.isTrashed == true, "AI-rejected Trash Undo should leave the Note in Trash")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(activeNotes.isEmpty, "AI-rejected Trash Undo should not restore the Note to active Notes")
}

func aiCannotRestoreNoteFromTrash() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let created = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Restore protected",
        body: "AI cannot restore this.",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: created.id))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.restoreNoteFromTrash(.init(noteID: created.id)), source: .ai)
    }

    let activeNotes = try notes(from: runtime.query(.notes))

    switch try runtime.query(.note(created.id)) {
    case .note(let note):
        try expect(note?.isTrashed == true, "AI-rejected restore should leave the Note in Trash")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(activeNotes.isEmpty, "AI-rejected restore should not return the Note to active Notes")
}

func userSearchWorksWithoutLocalModelProfileOverNoteTitles() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Local Runtime",
        body: "Harness boundary.",
        creationProvenance: .userCreated
    ))))
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "No matching title here.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let results = try userSearchResults(from: runtime.query(.userSearch("runtime")))

    try expect(results == [target], "User Search should return active Notes with matching Note Titles without a Local Model Profile")
}

func userSearchReturnsActiveNotesByKeywordMatchOverRawMarkdownNoteBodies() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "# Capture\n\nRaw **Markdown** mentions basalt samples.",
        creationProvenance: .userCreated
    ))))
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Log",
        body: "No matching body content.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let results = try userSearchResults(from: runtime.query(.userSearch("basalt")))

    try expect(results == [target], "User Search should return active Notes with matching raw Markdown Note Bodies")
}

func creatingANoteMarksUserSearchDerivedIndexDirty() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let initialFreshness = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Dirty Index",
        body: "Create should dirty search.",
        creationProvenance: .userCreated
    ))))
    let freshnessAfterCreate = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(initialFreshness == .fresh, "new User Search Derived Index should start fresh")
    try expect(freshnessAfterCreate == .dirty, "creating a Note should mark User Search Derived Index dirty")
}

func updatingANoteBodyMarksUserSearchDerivedIndexDirty() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Indexed Note",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let freshnessBeforeUpdate = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    _ = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
        noteID: note.id,
        body: "Updated body."
    ))))
    let freshnessAfterUpdate = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(freshnessBeforeUpdate == .fresh, "Indexing Jobs should refresh User Search Derived Index before update")
    try expect(freshnessAfterUpdate == .dirty, "updating a Note Body should mark User Search Derived Index dirty")
}

func renamingANoteMarksUserSearchDerivedIndexDirty() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Original Title",
        body: "Body.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let freshnessBeforeRename = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    _ = try renamedNote(from: runtime.execute(.renameNote(.init(
        noteID: note.id,
        title: "Renamed Title"
    ))))
    let freshnessAfterRename = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(freshnessBeforeRename == .fresh, "Indexing Jobs should refresh User Search Derived Index before rename")
    try expect(freshnessAfterRename == .dirty, "renaming a Note should mark User Search Derived Index dirty")
}

func movingANoteToTrashRemovesItFromRefreshedUserSearchResults() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Trash Search Target",
        body: "Recoverable content.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let resultsBeforeTrash = try userSearchResults(from: runtime.query(.userSearch("target")))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: note.id))))
    let freshnessAfterTrash = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let resultsAfterTrash = try userSearchResults(from: runtime.query(.userSearch("target")))

    try expect(resultsBeforeTrash == [note], "User Search should find active Notes before Trash")
    try expect(freshnessAfterTrash == .dirty, "moving a Note to Trash should mark User Search Derived Index dirty")
    try expect(resultsAfterTrash.isEmpty, "refreshed User Search should exclude Notes in Trash")
}

func restoringANoteFromTrashMarksUserSearchDerivedIndexDirty() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Restored Answer Target",
        body: "Basalt details should require refreshed retrieval after restore.",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: note.id))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let freshnessBeforeRestore = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    _ = try restoredNote(from: runtime.execute(.restoreNoteFromTrash(.init(noteID: note.id))))
    let freshnessAfterRestore = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    try expect(freshnessBeforeRestore == .fresh, "Indexing Jobs should refresh User Search Derived Index while Note is in Trash")
    try expect(freshnessAfterRestore == .dirty, "restoring a Note from Trash should mark User Search Derived Index dirty")
    try expectRuntimeError(.indexNotFresh(.userSearch)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func undoingTrashMarksUserSearchDerivedIndexDirty() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Undo Answer Target",
        body: "Basalt details should require refreshed retrieval after undo.",
        creationProvenance: .userCreated
    ))))
    let (_, undo) = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: note.id))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let freshnessBeforeUndo = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    _ = try restoredNote(from: runtime.execute(.undoTrash(.init(opportunity: undo))))
    let freshnessAfterUndo = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    try expect(freshnessBeforeUndo == .fresh, "Indexing Jobs should refresh User Search Derived Index while Note is in Trash")
    try expect(freshnessAfterUndo == .dirty, "undoing Trash should mark User Search Derived Index dirty")
    try expectRuntimeError(.indexNotFresh(.userSearch)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func aiAvailabilityReportsUnavailableWithoutLocalModelProfileWhileNotesAndUserSearchWork() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))

    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Offline capture",
        body: "Keyword search keeps working before AI setup.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let searchResults = try userSearchResults(from: runtime.query(.userSearch("keyword")))

    try expect(!isReady, "Device should not be AI-ready without a downloaded Local Model Profile")
    try expect(unavailableState == .noUsableLocalModelProfile, "AI Unavailable State should explain missing usable Local Model Profile")
    try expect(searchResults == [note], "Note-taking and User Search should remain available without an AI-ready Device")
}

func recordingLocalModelProfileMakesDeviceAIReadyAndChoosesIt() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profile = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Tiny"
    )

    let recorded = try localModelProfile(from: runtime.execute(.recordLocalModelProfile(.init(profile: profile))))
    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))

    try expect(recorded == profile, "recorded Local Model Profile should round-trip")
    try expect(inventory.downloadedProfiles == [profile], "Model Inventory should list downloaded Local Model Profiles")
    try expect(inventory.defaultProfileID == nil, "Model Inventory should allow no default Local Model Profile")
    try expect(isReady, "Device should be AI-ready with a downloaded Local Model Profile")
    try expect(unavailableState == nil, "AI Unavailable State should be omitted when a usable Local Model Profile exists")
    try expect(chosenProfile == profile, "runtime should choose the available Local Model Profile")
}

func refreshingModelAvailabilityFromAdapterRecordsDownloadedDefaultProfile() throws {
    let downloadedProfile = LocalModelProfile(
        id: .init("qvac-tiny"),
        name: "QVAC Tiny",
        isDownloaded: true,
        isRemovable: false
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(
        modelAvailability: AIRuntimeModelAvailability(
            isAIReady: true,
            inventory: ModelInventory(
                downloadedProfiles: [
                    downloadedProfile,
                    LocalModelProfile(
                        id: .init("qvac-large"),
                        name: "QVAC Large",
                        isDownloaded: false,
                        isRemovable: true
                    )
                ],
                defaultProfileID: downloadedProfile.id
            )
        )
    ))

    let updatedInventory = try updatedModelInventory(from: runtime.execute(.refreshModelAvailabilityFromAdapter(.init())))
    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))

    try expect(updatedInventory == ModelInventory(downloadedProfiles: [downloadedProfile], defaultProfileID: downloadedProfile.id), "refreshing Model Availability should return downloaded host profiles only")
    try expect(inventory == updatedInventory, "Model Inventory query should reflect refreshed host availability")
    try expect(chosenProfile == downloadedProfile, "runtime should choose the downloaded host default profile")
    try expect(isReady, "downloaded host model availability should make Device AI-ready")
    try expect(unavailableState == nil, "AI Unavailable State should be omitted when refreshed host availability is usable")
}

func refreshingUnavailableAdapterModelAvailabilityClearsStaleHostProfile() throws {
    let downloadedProfile = LocalModelProfile(
        id: .init("qvac-tiny"),
        name: "QVAC Tiny",
        isDownloaded: true,
        isRemovable: false
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(
        modelAvailabilityResponses: [
            AIRuntimeModelAvailability(
                isAIReady: true,
                inventory: ModelInventory(
                    downloadedProfiles: [downloadedProfile],
                    defaultProfileID: downloadedProfile.id
                )
            ),
            AIRuntimeModelAvailability(
                isAIReady: false,
                inventory: ModelInventory(
                    downloadedProfiles: [downloadedProfile],
                    defaultProfileID: downloadedProfile.id
                )
            )
        ]
    ))

    _ = try runtime.execute(.refreshModelAvailabilityFromAdapter(.init()))
    let refreshedInventory = try updatedModelInventory(from: runtime.execute(.refreshModelAvailabilityFromAdapter(.init())))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))

    try expect(refreshedInventory == ModelInventory(downloadedProfiles: [], defaultProfileID: nil), "unavailable host availability should clear stale adapter-sourced profiles")
    try expect(chosenProfile == nil, "unavailable host availability should leave no chosen host Local Model Profile")
    try expect(!isReady, "unavailable host availability should make Device not AI-ready when no manual profile exists")
    try expect(unavailableState == .noUsableLocalModelProfile, "unavailable host availability should surface missing usable Local Model Profile")
    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.requireAvailableLocalModelProfile()
    }
}

func refreshingAdapterModelAvailabilityPreservesUsableManualDefaultProfile() throws {
    let manualProfile = LocalModelProfile(
        id: .init("manual-model"),
        name: "Manual Local Model"
    )
    let adapterProfile = LocalModelProfile(
        id: .init("qvac-tiny"),
        name: "QVAC Tiny",
        isDownloaded: true,
        isRemovable: false
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(
        modelAvailability: AIRuntimeModelAvailability(
            isAIReady: true,
            inventory: ModelInventory(
                downloadedProfiles: [adapterProfile],
                defaultProfileID: adapterProfile.id
            )
        )
    ))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: manualProfile)))
    _ = try runtime.execute(.setDefaultLocalModelProfile(.init(profileID: manualProfile.id)))

    let refreshedInventory = try updatedModelInventory(from: runtime.execute(.refreshModelAvailabilityFromAdapter(.init())))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))

    try expect(refreshedInventory.downloadedProfiles == [manualProfile, adapterProfile], "adapter refresh should append host profiles without replacing manual profiles")
    try expect(refreshedInventory.defaultProfileID == manualProfile.id, "adapter refresh should preserve an existing usable manual default profile")
    try expect(chosenProfile == manualProfile, "runtime should keep choosing the manual default after adapter refresh")
}

func refreshingUnavailableAdapterModelAvailabilityPreservesManualProfileWithSameID() throws {
    let sharedProfileID = LocalModelProfileID("qvac-tiny")
    let manualProfile = LocalModelProfile(
        id: sharedProfileID,
        name: "Manual QVAC Tiny",
        isDownloaded: true,
        isRemovable: true
    )
    let adapterProfile = LocalModelProfile(
        id: sharedProfileID,
        name: "Host QVAC Tiny",
        isDownloaded: true,
        isRemovable: false
    )
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(
        modelAvailabilityResponses: [
            AIRuntimeModelAvailability(
                isAIReady: true,
                inventory: ModelInventory(
                    downloadedProfiles: [adapterProfile],
                    defaultProfileID: adapterProfile.id
                )
            ),
            AIRuntimeModelAvailability(
                isAIReady: false,
                inventory: ModelInventory(downloadedProfiles: [], defaultProfileID: nil)
            )
        ]
    ))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: manualProfile)))
    let inventoryAfterDownloadedRefresh = try updatedModelInventory(from: runtime.execute(.refreshModelAvailabilityFromAdapter(.init())))
    let inventoryAfterUnavailableRefresh = try updatedModelInventory(from: runtime.execute(.refreshModelAvailabilityFromAdapter(.init())))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))

    try expect(inventoryAfterDownloadedRefresh.downloadedProfiles == [manualProfile], "manual profile should win when adapter reports the same profile ID")
    try expect(inventoryAfterUnavailableRefresh.downloadedProfiles == [manualProfile], "unavailable adapter refresh should not delete a same-ID manual profile")
    try expect(chosenProfile == manualProfile, "runtime should keep choosing the manual same-ID profile after unavailable adapter refresh")
    try expect(isReady, "same-ID manual profile should keep Device AI-ready after unavailable adapter refresh")
    try expect(unavailableState == nil, "same-ID manual profile should prevent AI Unavailable State after unavailable adapter refresh")
}

func settingDefaultLocalModelProfileChoosesItFromMultipleProfiles() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profileA = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Tiny"
    )
    let profileB = LocalModelProfile(
        id: .init("model-b"),
        name: "QVAC Base"
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileA)))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileB)))
    _ = try runtime.execute(.setDefaultLocalModelProfile(.init(profileID: profileB.id)))

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))

    try expect(inventory.downloadedProfiles == [profileA, profileB], "Model Inventory should list multiple downloaded Local Model Profiles")
    try expect(inventory.defaultProfileID == profileB.id, "Model Inventory should expose the selected default Local Model Profile")
    try expect(chosenProfile == profileB, "runtime should choose the default Local Model Profile when available")
}

func clearingDefaultLocalModelProfileReturnsChoiceToFirstAvailableProfile() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profileA = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Tiny"
    )
    let profileB = LocalModelProfile(
        id: .init("model-b"),
        name: "QVAC Base"
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileA)))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileB)))
    _ = try runtime.execute(.setDefaultLocalModelProfile(.init(profileID: profileB.id)))
    _ = try runtime.execute(.clearDefaultLocalModelProfile(.init()))

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))

    try expect(inventory.defaultProfileID == nil, "Model Inventory should allow the default Local Model Profile to be cleared")
    try expect(chosenProfile == profileA, "runtime should choose the first available Local Model Profile after clearing default")
}

func removingDefaultLocalModelProfileClearsDefaultAndChoosesRemainingProfile() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profileA = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Tiny"
    )
    let profileB = LocalModelProfile(
        id: .init("model-b"),
        name: "QVAC Base"
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileA)))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profileB)))
    _ = try runtime.execute(.setDefaultLocalModelProfile(.init(profileID: profileB.id)))
    _ = try runtime.execute(.removeLocalModelProfile(.init(profileID: profileB.id)))

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))

    try expect(inventory.downloadedProfiles == [profileA], "removing a Local Model Profile should remove it from Model Inventory")
    try expect(inventory.defaultProfileID == nil, "removing the default Local Model Profile should clear default selection")
    try expect(chosenProfile == profileA, "runtime should choose the remaining Local Model Profile after default removal")
    try expect(isReady, "Device should stay AI-ready when another downloaded Local Model Profile remains")
}

func removingNonRemovableLocalModelProfileFailsAndLeavesInventoryUnchanged() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profile = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Built In",
        isRemovable: false
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))

    try expectRuntimeError(.localModelProfileNotRemovable(profile.id)) {
        _ = try runtime.execute(.removeLocalModelProfile(.init(profileID: profile.id)))
    }

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))

    try expect(inventory.downloadedProfiles == [profile], "non-removable Local Model Profile should remain in Model Inventory")
    try expect(chosenProfile == profile, "non-removable Local Model Profile should remain available for workflow choice")
    try expect(isReady, "Device should stay AI-ready after rejected non-removable profile removal")
}

func nonDownloadedLocalModelProfileDoesNotMakeDeviceAIReadyOrWorkflowSelectable() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profile = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Pending",
        isDownloaded: false
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))
    let isReady = try aiReadyDevice(from: runtime.query(.aiReadyDevice))
    let unavailableState = try aiUnavailableState(from: runtime.query(.aiUnavailableState))

    try expect(inventory.downloadedProfiles.isEmpty, "non-downloaded Local Model Profile should not appear as downloaded in Model Inventory")
    try expect(chosenProfile == nil, "non-downloaded Local Model Profile should not be chosen for workflows")
    try expect(!isReady, "non-downloaded Local Model Profile should not make Device AI-ready")
    try expect(unavailableState == .noUsableLocalModelProfile, "AI Unavailable State should remain missing usable Local Model Profile")
    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.requireAvailableLocalModelProfile()
    }
}

func settingDefaultToNonDownloadedLocalModelProfileFailsAndLeavesDefaultOmitted() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profile = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Pending",
        isDownloaded: false
    )

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))

    try expectRuntimeError(.localModelProfileNotFound(profile.id)) {
        _ = try runtime.execute(.setDefaultLocalModelProfile(.init(profileID: profile.id)))
    }

    let inventory = try modelInventory(from: runtime.query(.modelInventory))
    let chosenProfile = try chosenLocalModelProfile(from: runtime.query(.chosenLocalModelProfile))

    try expect(inventory.defaultProfileID == nil, "non-downloaded Local Model Profile should not become default")
    try expect(chosenProfile == nil, "non-downloaded default rejection should leave no chosen Local Model Profile")
}

func aiAvailabilityCheckFailsFastUntilUsableLocalModelProfileExists() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.requireAvailableLocalModelProfile()
    }

    let profile = LocalModelProfile(
        id: .init("model-a"),
        name: "QVAC Tiny"
    )
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))

    let availableProfile = try runtime.requireAvailableLocalModelProfile()

    try expect(availableProfile == profile, "AI availability check should return the chosen Local Model Profile once available")
}

func answerRequestDefaultsToNoteGroundedAndReturnsSourceCitations() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from the ridge trail.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let result = try runtime.answer(.init(prompt: "basalt"))

    try expect(result.mode == .noteGrounded, "Answer Request should default to note-grounded mode")
    try expect(result.modeLabel == "Note-grounded Answer", "note-grounded result should be explicitly labeled")
    try expect(result.isConstrainedToRetrievedNotes, "note-grounded result should be constrained to retrieved Notes")
    try expect(result.citations == [
        SourceCitation(noteID: note.id, noteFragmentID: "note-body")
    ], "note-grounded result should cite the matched Note content")
    try expect(result.answer == "Note-grounded Answer: basalt [Field Note]", "fake adapter should format deterministic note-grounded answers")
}

func noteGroundedAnswerFailsFastWithoutAIReadyDevice() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from the ridge trail.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func noteGroundedAnswerRequiresFreshUserSearchIndex() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from the ridge trail.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    try expectRuntimeError(.indexNotFresh(.userSearch)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func noteGroundedRetrievalExpandsThroughExplicitLinks() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let linked = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Ridge Detail",
        body: "The ridge trail sits above the north valley.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from [[Ridge Detail]].",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let result = try runtime.answer(.init(prompt: "basalt"))

    try expect(result.citations == [
        SourceCitation(noteID: source.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: linked.id, noteFragmentID: "note-body")
    ], "Context Retrieval should cite the matched Note and its Explicit Link expansion")
    try expect(result.answer == "Note-grounded Answer: basalt [Field Note, Ridge Detail]", "fake adapter should receive Explicit Link-expanded context in citation order")
}

func noteGroundedRetrievalExpandsThroughAcceptedRelationships() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from the ridge trail.",
        creationProvenance: .userCreated
    ))))
    let related = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Lab Result",
        body: "The sample has high iron content.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: source.id,
        targetNoteID: related.id
    )))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let result = try runtime.answer(.init(prompt: "basalt"))

    try expect(result.citations == [
        SourceCitation(noteID: source.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: related.id, noteFragmentID: "note-body")
    ], "Context Retrieval should cite the matched Note and its Accepted Relationship expansion")
    try expect(result.answer == "Note-grounded Answer: basalt [Field Note, Lab Result]", "fake adapter should receive Accepted Relationship-expanded context")
}

func noteGroundedRetrievalWeightsExplicitLinksBeforeAcceptedRelationships() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let explicitA = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Ridge Detail",
        body: "The ridge trail sits above the north valley.",
        creationProvenance: .userCreated
    ))))
    let explicitB = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Sample Detail",
        body: "The second sample was dry.",
        creationProvenance: .userCreated
    ))))
    let accepted = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Lab Result",
        body: "The lab result has high iron content.",
        creationProvenance: .userCreated
    ))))
    let sourceA = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt sample alpha links to [[Ridge Detail]].",
        creationProvenance: .userCreated
    ))))
    let sourceB = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Second Field Note",
        body: "Basalt sample beta links to [[Sample Detail]].",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: sourceA.id,
        targetNoteID: accepted.id
    )))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let result = try runtime.answer(.init(prompt: "basalt"))

    try expect(result.citations == [
        SourceCitation(noteID: sourceA.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: sourceB.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: explicitA.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: explicitB.id, noteFragmentID: "note-body"),
        SourceCitation(noteID: accepted.id, noteFragmentID: "note-body")
    ], "Explicit Link expansions should rank ahead of Accepted Relationship expansions")
}

func noteGroundedAnswerDoesNotUsePlaceholderOrTrashAsFallbackContext() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Placeholder",
        body: "",
        creationProvenance: .placeholderCreated
    ))))
    let trash = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Trash",
        body: "Basalt content in Trash should not ground answers.",
        creationProvenance: .userCreated
    ))))
    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: trash.id))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    try expectRuntimeError(.noRetrievedContext(.noteGrounded)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func noContextNoteGroundedAnswerRequiresGeneralFallbackConfirmation() throws {
    try expect(
        AnswerFallbackPolicy.requiresGeneralFallbackConfirmation(
            after: RuntimeError.noRetrievedContext(.noteGrounded),
            attemptedMode: .noteGrounded
        ),
        "Note-grounded Answer with no retrieved context should ask before General AI fallback"
    )
    try expect(
        !AnswerFallbackPolicy.requiresGeneralFallbackConfirmation(
            after: RuntimeError.noRetrievedContext(.noteGrounded),
            attemptedMode: .general
        ),
        "General AI Answer should not ask for General fallback again"
    )
}

func sourceCitationPresentationKeepsNoteTitleStableIDAndFragmentSeparate() throws {
    let noteID = NoteID("runtime-note-42")
    let presentation = PresentationSourceCitation(
        citation: SourceCitation(noteID: noteID, noteFragmentID: "note-body"),
        noteTitle: "Field Note"
    )

    try expect(presentation.noteID == "runtime-note-42", "display Source Citation should expose stable Note ID")
    try expect(presentation.noteTitle == "Field Note", "display Source Citation should expose Note Title when known")
    try expect(presentation.noteFragmentID == "note-body", "display Source Citation should expose Note Fragment ID separately")
    try expect(presentation.displayTitle == "Field Note", "display Source Citation should prefer Note Title")

    let titleless = PresentationSourceCitation(
        citation: SourceCitation(noteID: noteID, noteFragmentID: "note-body"),
        noteTitle: nil
    )
    try expect(titleless.displayTitle == "runtime-note-42", "display Source Citation should fall back to stable Note ID")
}

func chatAnswerRequestGuardPreventsCanceledAndStaleResultsFromApplying() throws {
    var guardState = ChatAnswerRequestGuard()

    guardState.begin(requestID: "first")
    try expect(guardState.canApplyResult(for: "first"), "active request should be allowed to update chat UI")

    guardState.cancelActive()
    try expect(!guardState.canApplyResult(for: "first"), "canceled request should not update chat UI")

    guardState.begin(requestID: "second")
    try expect(!guardState.canApplyResult(for: "first"), "older request should not update chat UI after a newer request begins")
    try expect(guardState.canApplyResult(for: "second"), "latest non-canceled request should be allowed to update chat UI")

    guardState.finish(requestID: "second")
    try expect(!guardState.canApplyResult(for: "second"), "finished request should no longer be active")
}

func chatAnswerPresentationStateClearsStaleCitationsAndErrorsForNewAndCanceledRequests() throws {
    var state = ChatAnswerPresentationState(
        citations: [
            PresentationSourceCitation(
                citation: SourceCitation(noteID: NoteID("old-note"), noteFragmentID: "note-body"),
                noteTitle: "Old Note"
            )
        ],
        errorMessage: "Old error"
    )

    state.prepareForNewAnswer()

    try expect(state.citations.isEmpty, "new chat answer should clear stale Source Citations before loading")
    try expect(state.errorMessage == nil, "new chat answer should clear stale error before loading")

    state.citations = [
        PresentationSourceCitation(
            citation: SourceCitation(noteID: NoteID("cancel-note"), noteFragmentID: "note-body"),
            noteTitle: "Canceled Note"
        )
    ]
    state.errorMessage = "Canceled error"

    state.clearAfterCancellation()

    try expect(state.citations.isEmpty, "canceled chat answer should clear stale Source Citations")
    try expect(state.errorMessage == nil, "canceled chat answer should clear stale error")
}

func aiSessionHistoryPresentationMapsRuntimeMetadata() throws {
    let createdAt = Date(timeIntervalSince1970: 1_830_000_300)
    let entry = AISessionHistoryEntry(
        id: .init("ai-session-history-1"),
        prompt: "basalt texture",
        response: "Basalt is fine-grained.",
        mode: .noteGrounded,
        createdAt: createdAt,
        citations: [SourceCitation(noteID: .init("note-basalt"), noteFragmentID: "note-body")]
    )

    let presentation = PresentationAISessionHistoryEntry(entry: entry) { noteID in
        noteID == NoteID("note-basalt") ? "Basalt field guide" : nil
    }

    try expect(presentation.id == entry.id, "AI Session History presentation should keep stable runtime ID")
    try expect(presentation.prompt == entry.prompt, "AI Session History presentation should keep prompt")
    try expect(presentation.response == entry.response, "AI Session History presentation should keep response")
    try expect(presentation.mode == .noteGrounded, "AI Session History presentation should keep Answer Mode")
    try expect(presentation.modeLabel == "Note-grounded Answer", "AI Session History presentation should expose Answer Mode label")
    try expect(presentation.createdAt == createdAt, "AI Session History presentation should keep creation timestamp")
    try expect(presentation.citations == [
        PresentationSourceCitation(
            citation: .init(noteID: .init("note-basalt"), noteFragmentID: "note-body"),
            noteTitle: "Basalt field guide"
        )
    ], "AI Session History presentation should map runtime Source Citations with display titles")
}

func chatHistoryDeletionPresentationStateSurfacesAndClearsDeleteFailures() throws {
    var state = ChatHistoryDeletionPresentationState()

    state.didFailToDelete()

    try expect(
        state.errorMessage == "This chat history entry could not be deleted.",
        "failed Chat History deletion should expose a user-facing error message"
    )

    state.didDeleteSuccessfully()

    try expect(
        state.errorMessage == nil,
        "successful Chat History deletion should clear stale delete errors"
    )
}

func developmentModelProfilePolicyRequiresExplicitOptIn() throws {
    try expect(
        !DevelopmentModelProfilePolicy.isOptedIn(environment: [:], arguments: []),
        "debug fake Local Model Profile should be disabled without explicit opt-in"
    )
    try expect(
        DevelopmentModelProfilePolicy.isOptedIn(
            environment: ["QVAC_ENABLE_DEBUG_FAKE_MODEL_PROFILE": "1"],
            arguments: []
        ),
        "debug fake Local Model Profile should be enabled by explicit environment opt-in"
    )
    try expect(
        DevelopmentModelProfilePolicy.isOptedIn(
            environment: [:],
            arguments: ["qvac2026", "-QVACEnableDebugFakeModelProfile"]
        ),
        "debug fake Local Model Profile should be enabled by explicit launch argument opt-in"
    )
}

func placeholderSeedCannotExpandContextRetrievalThroughGraph() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let placeholder = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Placeholder",
        body: "",
        creationProvenance: .placeholderCreated
    ))))
    let related = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Related Evidence",
        body: "This real note must not be reached through placeholder retrieval.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.createAcceptedRelationship(.init(
        sourceNoteID: placeholder.id,
        targetNoteID: related.id
    )))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    try expectRuntimeError(.noRetrievedContext(.noteGrounded)) {
        _ = try runtime.answer(.init(prompt: "basalt"))
    }
}

func generalAnswerIsExplicitlyUnconstrainedAndDoesNotRequireFreshIndex() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Note",
        body: "Basalt samples came from the ridge trail.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    _ = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
        noteID: note.id,
        body: "Basalt samples were revised after indexing."
    ))))

    let result = try runtime.answer(.init(prompt: "basalt", mode: .general))

    try expect(result.mode == .general, "General Answer should keep explicit general mode")
    try expect(result.modeLabel == "General AI Answer: not constrained to retrieved Notes", "General Answer should be explicitly labeled as not constrained")
    try expect(!result.isConstrainedToRetrievedNotes, "General Answer should not be constrained to retrieved Notes")
    try expect(result.citations.isEmpty, "General Answer should not return Source Citations")
    try expect(result.answer == "General AI Answer: not constrained to retrieved Notes: basalt []", "fake adapter should receive no retrieved Note context for General Answer")
}

func aiAnswersAreRecordedInLocalAISessionHistoryByDefault() throws {
    let now = Date(timeIntervalSince1970: 1_830_000_100)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.answer(.init(prompt: "draft a basalt checklist", mode: .general))
    let history = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    try expect(history == [
        AISessionHistoryEntry(
            id: .init("ai-session-history-1"),
            prompt: "draft a basalt checklist",
            response: result.answer,
            mode: .general,
            createdAt: now,
            citations: []
        )
    ], "AI answers should be recorded in local AI Session History by default")
}

func aiSessionHistoryRecordsAnswerMetadata() throws {
    let now = Date(timeIntervalSince1970: 1_830_000_000)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt field guide",
        body: "Basalt has a fine-grained texture.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    let result = try runtime.answer(.init(prompt: "basalt texture", mode: .noteGrounded))
    let history = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    try expect(history == [
        AISessionHistoryEntry(
            id: .init("ai-session-history-1"),
            prompt: "basalt texture",
            response: result.answer,
            mode: .noteGrounded,
            createdAt: now,
            citations: [SourceCitation(noteID: note.id, noteFragmentID: "note-body")]
        )
    ], "AI Session History should record timestamp and runtime Source Citations from the answer")
}

func aiSessionHistoryCanBeDeletedThroughRuntimeCommand() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.answer(.init(prompt: "draft a basalt checklist", mode: .general))
    let entry = try aiSessionHistory(from: runtime.query(.aiSessionHistory))[0]

    let deletedEntryID = try deletedAISessionHistoryEntryID(from: runtime.execute(.deleteAISessionHistoryEntry(.init(entryID: entry.id))))
    let historyAfterDelete = try aiSessionHistory(from: runtime.query(.aiSessionHistory))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let historyAfterUnrelatedCommand = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    try expect(deletedEntryID == entry.id, "delete command should return deleted AI Session History entry ID")
    try expect(historyAfterDelete.isEmpty, "deleted AI Session History entry should be removed")
    try expect(historyAfterUnrelatedCommand.isEmpty, "deleted AI Session History entry should stay removed")
}

func aiCannotDeleteAISessionHistory() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.answer(.init(prompt: "draft a basalt checklist", mode: .general))
    let historyBeforeRejectedDelete = try aiSessionHistory(from: runtime.query(.aiSessionHistory))
    let entry = historyBeforeRejectedDelete[0]

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.deleteAISessionHistoryEntry(.init(entryID: entry.id)), source: .ai)
    }

    let historyAfterRejectedDelete = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    try expect(historyAfterRejectedDelete == historyBeforeRejectedDelete, "AI-rejected delete should leave AI Session History intact")
}

func aiSessionHistoryIsExcludedFromContextRetrieval() throws {
    let now = Date(timeIntervalSince1970: 1_830_000_200)
    let runtime = RuntimeCoreHarness.makeInMemory(clock: { now })
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    let result = try runtime.answer(.init(prompt: "historiolith appears only in AI Session History", mode: .general))
    _ = try runtime.execute(.runIndexingJobs(.init()))

    try expectRuntimeError(.noRetrievedContext(.noteGrounded)) {
        _ = try runtime.answer(.init(prompt: "historiolith"))
    }

    let history = try aiSessionHistory(from: runtime.query(.aiSessionHistory))

    try expect(history == [
        AISessionHistoryEntry(
            id: .init("ai-session-history-1"),
            prompt: "historiolith appears only in AI Session History",
            response: result.answer,
            mode: .general,
            createdAt: now,
            citations: []
        )
    ], "failed note-grounded retrieval should not consume or delete AI Session History")
}

func aiGeneratedWriteRequiresExplicitDestinationBeforeDurableResult() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed(["Generated body."])))
    let sessionID = AISessionID("ai-session-1")

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    try expectRuntimeError(.aiWriteDestinationRequired) {
        _ = try runtime.execute(.runAIWriteWorkflow(.init(
            sessionID: sessionID,
            prompt: "Draft a note",
            destination: nil
        )))
    }

    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(activeNotes.isEmpty, "rejected AI write without destination should create no Note")
    try expect(operations.isEmpty, "rejected AI write without destination should create no AI Operation")
}

func aiSourceCannotBypassAIWriteModelWithDirectNoteMutations() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.createNote(.init(
            title: "AI bypass",
            body: "Durable AI body without destination.",
            creationProvenance: .aiCreated
        )), source: .ai)
    }

    let userNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "User note",
        body: "Original user body.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.updateNoteBody(.init(
            noteID: userNote.id,
            body: "AI bypass update."
        )), source: .ai)
    }

    let stored = try note(from: runtime.query(.note(userNote.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == userNote, "AI-rejected direct update should leave the Note unchanged")
    try expect(activeNotes == [userNote], "AI-rejected direct create should not add a Note")
    try expect(operations.isEmpty, "AI-rejected direct mutations should not create AI Operations")
}

func aiSourceCannotBypassAIWriteModelWithRenameOrSavedResponse() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let userNote = try createdNote(from: runtime.execute(.createNote(.init(
        title: "User note",
        body: "Original user body.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.renameNote(.init(
            noteID: userNote.id,
            title: "AI rename"
        )), source: .ai)
    }

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.saveAIResponse(.init(
            response: "Saved AI body with [[AI Placeholder]].",
            destination: .newNote(title: "AI saved response")
        )), source: .ai)
    }

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.saveAIResponse(.init(
            response: "Draft AI body.",
            destination: .draftChange(noteID: userNote.id)
        )), source: .ai)
    }

    let stored = try note(from: runtime.query(.note(userNote.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == userNote, "AI-rejected rename should leave Note Title unchanged")
    try expect(activeNotes == [userNote], "AI-rejected Saved AI Response should create no Note or Placeholder Note")
    try expect(operations.isEmpty, "AI-rejected Saved AI Response should create no AI Operation")
    try expectRuntimeError(.draftChangeNotFound(.init("draft-change-1"))) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: .init("draft-change-1"))))
    }
}

func aiSourceCannotSetEditingPermissionOrAcceptDraftChange() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed(["Draft body."])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
            sessionID: sessionID,
            mode: .directEdit
        ))), source: .ai)
    }

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(source.id)
    ))))
    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "AI-rejected Direct Edit permission should leave the session in draft mode")
    }

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id)), source: .ai)
    }

    let stored = try note(from: runtime.query(.note(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == source, "AI-rejected Draft Change acceptance should leave Note Body unchanged")
    try expect(operations.isEmpty, "AI-rejected Draft Change acceptance should create no AI Operation")
}

func aiCannotCancelDraftChange() throws {
    let generatedBody = "AI draft body."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(source.id)
    ))))
    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to create a Draft Change")
    }

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.cancelDraftChange(.init(draftChangeID: draftChange.id)), source: .ai)
    }

    let storedBeforeAccept = try note(from: runtime.query(.note(source.id)))
    let operationsBeforeAccept = try aiOperations(from: runtime.query(.aiOperations))

    try expect(storedBeforeAccept == source, "AI-rejected Draft Change cancel should leave Note Body unchanged")
    try expect(operationsBeforeAccept.isEmpty, "AI-rejected Draft Change cancel should create no AI Operation")

    _ = try acceptedDraftChangeOperation(from: runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id))))
    let storedAfterAccept = try note(from: runtime.query(.note(source.id)))

    try expect(storedAfterAccept?.body == generatedBody, "AI-rejected Draft Change cancel should leave the Draft Change user-acceptable")
}

func acceptingDraftChangeAppliesGeneratedContentLinksAndRecordsAIOperation() throws {
    let generatedBody = "AI body links to [[Basalt Detail]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let profile = LocalModelProfile(id: .init("model-a"), name: "QVAC Tiny")
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Detail",
        body: "Existing link target.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(source.id)
    ))))

    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to create a Draft Change")
    }

    switch try runtime.query(.note(source.id)) {
    case .note(let note):
        try expect(note == source, "Draft Change should not mutate Note Body before acceptance")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    let linksBeforeAccept = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    try expect(linksBeforeAccept.isEmpty, "Draft Change should not mutate Explicit Links before acceptance")

    let operation = try acceptedDraftChangeOperation(from: runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id))))
    let updated = try note(from: runtime.query(.note(source.id)))
    let linksAfterAccept = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(updated?.body == generatedBody, "accepted Draft Change should update Note Body")
    try expect(linksAfterAccept == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: generatedBody
        )
    ], "accepted Draft Change should create durable Explicit Links from generated Wikilinks")
    try expect(operation.localModelProfileID == profile.id, "accepted Draft Change operation should record the Local Model Profile")
    try expect(operation.changes == [
        AIChange(noteID: source.id, previousNote: source, newNote: updated)
    ], "accepted Draft Change operation should record one note-level AI Change")
    try expect(operations == [operation], "accepted Draft Change operation should be durable")
}

func cancelingDraftChangeCreatesNoDurableNoteGraphOrOperationResult() throws {
    let generatedBody = "Canceled body links to [[Basalt Detail]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note",
        destination: .existingNote(source.id)
    ))))

    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to create a Draft Change")
    }

    let canceledID = try canceledDraftChangeID(from: runtime.execute(.cancelDraftChange(.init(draftChangeID: draftChange.id))))
    let stored = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(canceledID == draftChange.id, "canceling Draft Change should return the canceled Draft Change ID")
    try expect(stored == source, "canceling Draft Change should not mutate Note Body")
    try expect(links.isEmpty, "canceling Draft Change should not create Explicit Links")
    try expect(operations.isEmpty, "canceling Draft Change should not create an AI Operation")
    try expectRuntimeError(.draftChangeNotFound(draftChange.id)) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id)))
    }
}

func draftAcceptanceDoesNotMutateNoteOrGraphWhenAIOperationCommitFails() throws {
    let generatedBody = "Failed draft body links to [[Failed Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note as draft",
        destination: .existingNote(source.id)
    ))))
    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to create a Draft Change")
    }

    _ = try runtime.execute(.failNextAIOperationCommit(.init()))

    try expectRuntimeError(.aiOperationCommitFailed) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id)))
    }

    let stored = try note(from: runtime.query(.note(source.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == source, "failed Draft acceptance operation commit should leave Note Body unchanged")
    try expect(activeNotes == [source], "failed Draft acceptance operation commit should not create Placeholder Notes")
    try expect(links.isEmpty, "failed Draft acceptance operation commit should not create Explicit Links")
    try expect(operations.isEmpty, "failed Draft acceptance operation commit should leave no AI Operation")

    let recoveredOperation = try acceptedDraftChangeOperation(from: runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id))))
    try expect(recoveredOperation.changes.count == 1, "failed Draft acceptance should leave the Draft Change available for a later user acceptance")
}

func directEditAppliesGeneratedContentImmediatelyAndRecordsAIOperation() throws {
    let generatedBody = "Direct body links to [[Basalt Detail]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let profile = LocalModelProfile(id: .init("model-a"), name: "QVAC Tiny")
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Detail",
        body: "Existing link target.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.runIndexingJobs(.init()))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note directly",
        destination: .existingNote(source.id)
    ))))

    guard case .directEdit(let operation) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to apply a Direct Edit")
    }

    let updated = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let freshness = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(updated?.body == generatedBody, "Direct Edit should update Note Body immediately")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: target.id,
            snippet: generatedBody
        )
    ], "Direct Edit should create durable Explicit Links from generated Wikilinks")
    try expect(operation.localModelProfileID == profile.id, "Direct Edit operation should record the Local Model Profile")
    try expect(operation.changes == [
        AIChange(noteID: source.id, previousNote: source, newNote: updated)
    ], "Direct Edit operation should record one note-level AI Change")
    try expect(operations == [operation], "Direct Edit operation should be durable")
    try expect(freshness == .dirty, "Direct Edit should mark User Search Derived Index dirty")
}

func directEditCommitsAtomicallyWhenOneOfMultipleChangesIsInvalid() throws {
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([
        "Partial body should not apply.",
        "Missing target body."
    ])))
    let sessionID = AISessionID("ai-session-1")
    let existing = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Existing Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    let missing = NoteID("missing-note")

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    try expectRuntimeError(.noteNotFound(missing)) {
        _ = try runtime.execute(.runAIWriteWorkflow(.init(
            sessionID: sessionID,
            prompt: "Edit two notes",
            destinations: [
                .existingNote(existing.id),
                .existingNote(missing)
            ]
        )))
    }

    let stored = try note(from: runtime.query(.note(existing.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == existing, "failed multi-note Direct Edit should not partially update earlier Notes")
    try expect(operations.isEmpty, "failed multi-note Direct Edit should not commit an AI Operation")
}

func directEditDoesNotMutateNoteOrGraphWhenAIOperationCommitFails() throws {
    let generatedBody = "Failed body links to [[Failed Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))
    _ = try runtime.execute(.failNextAIOperationCommit(.init()))

    try expectRuntimeError(.aiOperationCommitFailed) {
        _ = try runtime.execute(.runAIWriteWorkflow(.init(
            sessionID: sessionID,
            prompt: "Revise note directly",
            destination: .existingNote(source.id)
        )))
    }

    let stored = try note(from: runtime.query(.note(source.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == source, "failed Direct Edit operation commit should leave Note Body unchanged")
    try expect(activeNotes == [source], "failed Direct Edit operation commit should not create Placeholder Notes")
    try expect(links.isEmpty, "failed Direct Edit operation commit should not create Explicit Links")
    try expect(operations.isEmpty, "failed Direct Edit operation commit should leave no AI Operation")
}

func reversingDirectEditRestoresPreviousNoteContentAndGraphSideEffects() throws {
    let generatedBody = "Generated link points to [[New Target]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let oldTarget = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Old Target",
        body: "Existing old target.",
        creationProvenance: .userCreated
    ))))
    let newTarget = try createdNote(from: runtime.execute(.createNote(.init(
        title: "New Target",
        body: "Existing new target.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original link points to [[Old Target]].",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note directly",
        destination: .existingNote(source.id)
    ))))
    guard case .directEdit(let operation) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to apply a Direct Edit")
    }

    let reversed = try reversedAIOperation(from: runtime.execute(.reverseAIOperation(.init(operationID: operation.id))))
    let restored = try note(from: runtime.query(.note(source.id)))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let oldBacklinks = try backlinks(from: runtime.query(.backlinks(oldTarget.id)))
    let newBacklinks = try backlinks(from: runtime.query(.backlinks(newTarget.id)))

    try expect(restored == source, "reversing Direct Edit should restore previous Note state")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: oldTarget.id,
            snippet: "Original link points to [[Old Target]]."
        )
    ], "reversing Direct Edit should restore previous Explicit Links")
    try expect(oldBacklinks == [
        Backlink(
            sourceNoteID: source.id,
            sourceNoteTitle: source.title,
            targetNoteID: oldTarget.id,
            snippet: "Original link points to [[Old Target]]."
        )
    ], "reversing Direct Edit should restore previous Backlinks")
    try expect(newBacklinks.isEmpty, "reversing Direct Edit should remove generated Backlinks")
    try expect(reversed.isReversed, "reversing Direct Edit should mark the AI Operation reversed")
}

func generatedUnresolvedWikilinksCreateDisambiguatedPlaceholderNotesWhenContentBecomesDurable() throws {
    let generatedBody = "Generated structure points to [[Future Topic]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let trashed = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Future Topic",
        body: "This title exists only in Trash.",
        creationProvenance: .userCreated
    ))))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try movedNoteToTrash(from: runtime.execute(.moveNoteToTrash(.init(noteID: trashed.id))))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    _ = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note directly",
        destination: .existingNote(source.id)
    ))))

    let activeNotes = try notes(from: runtime.query(.notes))
    guard let placeholder = activeNotes.first(where: { $0.title == "Future Topic (2)" }) else {
        throw BehaviorTestFailure(description: "AI-generated unresolved Wikilink should create a disambiguated Placeholder Note")
    }
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))

    try expect(placeholder.isPlaceholder, "AI-generated unresolved Wikilink should create a Placeholder Note")
    try expect(placeholder.creationProvenance == .placeholderCreated, "AI-generated Placeholder Note should record placeholder Creation Provenance")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: source.id,
            targetNoteID: placeholder.id,
            snippet: generatedBody
        )
    ], "AI-generated unresolved Wikilink should create an Explicit Link to the active Placeholder Note")
}

func reversingDirectEditRemovesPlaceholderNoteCreatedByGeneratedWikilink() throws {
    let generatedBody = "Generated structure points to [[AI Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note directly",
        destination: .existingNote(source.id)
    ))))
    guard case .directEdit(let operation) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to apply a Direct Edit")
    }
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "AI Placeholder" }) else {
        throw BehaviorTestFailure(description: "expected generated Wikilink to create a Placeholder Note")
    }

    _ = try reversedAIOperation(from: runtime.execute(.reverseAIOperation(.init(operationID: operation.id))))

    let activeNotes = try notes(from: runtime.query(.notes))
    let graph = try trustedGraph(from: runtime.query(.trustedGraph))

    switch try runtime.query(.note(placeholder.id)) {
    case .note(let storedPlaceholder):
        try expect(storedPlaceholder?.isTrashed == true, "reversing should move the AI-created Placeholder Note out of the active corpus")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(activeNotes == [source], "reversing should remove the AI-created Placeholder Note from active Notes")
    try expect(!graph.nodes.contains { $0.noteID == placeholder.id }, "reversing should remove the AI-created Placeholder Note from Trusted Graph")
}

func simulatedCrashDiscardsIncompleteAIOperationWithoutPartialNoteChange() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let original = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Crash Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    let plannedNote = Note(
        id: original.id,
        title: original.title,
        body: "Partial body should never commit.",
        creationProvenance: original.creationProvenance,
        isPlaceholder: original.isPlaceholder,
        isTrashed: original.isTrashed
    )

    let pendingID = try incompleteAIOperationID(from: runtime.execute(.beginIncompleteAIOperation(.init(
        localModelProfileID: .init("model-a"),
        changes: [
            AIChange(noteID: original.id, previousNote: original, newNote: plannedNote)
        ]
    ))))
    _ = try runtime.execute(.simulateCrashRestart(.init()))

    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let stored = try note(from: runtime.query(.note(original.id)))

    try expect(operations.isEmpty, "simulated restart should discard incomplete AI Operations")
    try expect(stored == original, "simulated crash should not apply partial Note changes")
    try expectRuntimeError(.aiOperationNotFound(pendingID)) {
        _ = try runtime.execute(.reverseAIOperation(.init(operationID: pendingID)))
    }
}

func simulatedIncompleteDirectAIWriteLeavesNoPartialNoteGraphOrOperationChange() throws {
    let generatedBody = "Partial body links to [[Partial Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Direct Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    _ = try runtime.execute(.simulateIncompleteAIWriteWorkflow(.init(workflow: .init(
        sessionID: sessionID,
        prompt: "Revise note directly",
        destination: .existingNote(source.id)
    ))))

    let stored = try note(from: runtime.query(.note(source.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == source, "simulated incomplete Direct Edit should leave Note Body unchanged")
    try expect(activeNotes == [source], "simulated incomplete Direct Edit should not create Placeholder Notes")
    try expect(links.isEmpty, "simulated incomplete Direct Edit should not create Explicit Links")
    try expect(operations.isEmpty, "simulated incomplete Direct Edit should not commit an AI Operation")
}

func simulatedIncompleteDraftAcceptanceLeavesNoPartialNoteGraphOrOperationChange() throws {
    let generatedBody = "Partial draft body links to [[Partial Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(generatedNoteBodies: .completed([generatedBody])))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    let workflowResult = try aiWriteWorkflow(from: runtime.execute(.runAIWriteWorkflow(.init(
        sessionID: sessionID,
        prompt: "Revise note as draft",
        destination: .existingNote(source.id)
    ))))
    guard case .draftChange(let draftChange) = workflowResult else {
        throw BehaviorTestFailure(description: "expected AI write to create a Draft Change")
    }

    _ = try runtime.execute(.simulateIncompleteDraftAcceptance(.init(draftChangeID: draftChange.id)))

    let stored = try note(from: runtime.query(.note(source.id)))
    let activeNotes = try notes(from: runtime.query(.notes))
    let links = try explicitLinks(from: runtime.query(.explicitLinks(source.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(stored == source, "simulated incomplete Draft acceptance should leave Note Body unchanged")
    try expect(activeNotes == [source], "simulated incomplete Draft acceptance should not create Placeholder Notes")
    try expect(links.isEmpty, "simulated incomplete Draft acceptance should not create Explicit Links")
    try expect(operations.isEmpty, "simulated incomplete Draft acceptance should not commit an AI Operation")
}

func savingAIResponseToNewNoteCreatesNoteContentLinksIndexAndOperationMarker() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Detail",
        body: "Existing note for link resolution.",
        creationProvenance: .userCreated
    ))))
    _ = try runtime.execute(.runIndexingJobs(.init()))
    let response = "Saved response links to [[Basalt Detail]]."

    let saved = try savedAIResponse(from: runtime.execute(.saveAIResponse(.init(
        response: response,
        destination: .newNote(title: "Saved AI Response")
    ))))

    guard case .note(let note) = saved.destination else {
        throw BehaviorTestFailure(description: "expected Saved AI Response new Note destination")
    }

    let links = try explicitLinks(from: runtime.query(.explicitLinks(note.id)))
    let freshness = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(saved.id == .init("saved-ai-response-1"), "Saved AI Response should expose a local ID")
    try expect(note.title == "Saved AI Response", "new Note destination should use requested Note Title")
    try expect(note.body == response, "new Note destination should store response text as Note Body")
    try expect(note.creationProvenance == .aiCreated, "new Note destination should record AI Creation Provenance")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: note.id,
            targetNoteID: target.id,
            snippet: "Saved response links to [[Basalt Detail]]."
        )
    ], "new Note destination should preserve Explicit Link side effects")
    try expect(freshness == .dirty, "new Note destination should mark User Search Derived Index dirty")
    try expect(saved.aiOperation == AIOperation(
        id: .init("ai-operation-1"),
        createdNoteID: note.id,
        isReversed: false
    ), "new Note destination should create a reversible AI Operation marker")
}

func savingAIResponseToNewNoteRecordsChosenLocalModelProfileInAIOperation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let profile = LocalModelProfile(id: .init("model-a"), name: "QVAC Tiny")

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: profile)))

    let saved = try savedAIResponse(from: runtime.execute(.saveAIResponse(.init(
        response: "Saved response body.",
        destination: .newNote(title: "Saved AI Response")
    ))))

    guard case .note(let note) = saved.destination, let operation = saved.aiOperation else {
        throw BehaviorTestFailure(description: "expected Saved AI Response new Note and AI Operation")
    }

    try expect(operation.localModelProfileID == profile.id, "Saved AI Response operation should record the chosen Local Model Profile")
    try expect(operation.changes == [
        AIChange(noteID: note.id, previousNote: nil, newNote: note)
    ], "Saved AI Response operation should record the created Note AI Change")
}

func reversingSavedAIResponseOperationRemovesCreatedNoteFromActiveNotes() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let saved = try savedAIResponse(from: runtime.execute(.saveAIResponse(.init(
        response: "Saved response body.",
        destination: .newNote(title: "Saved AI Response")
    ))))
    guard case .note(let note) = saved.destination, let operation = saved.aiOperation else {
        throw BehaviorTestFailure(description: "expected Saved AI Response new Note and AI Operation")
    }

    let reversed = try reversedAIOperation(from: runtime.execute(.reverseAIOperation(.init(operationID: operation.id))))
    let activeNotes = try notes(from: runtime.query(.notes))
    let freshness = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    switch try runtime.query(.note(note.id)) {
    case .note(let storedNote):
        try expect(storedNote?.isTrashed == true, "reversing the AI Operation should move the created Note out of the active corpus")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(reversed == AIOperation(
        id: operation.id,
        createdNoteID: note.id,
        isReversed: true
    ), "reversing should return the reversed AI Operation marker")
    try expect(!activeNotes.contains { $0.id == note.id }, "reversed Saved AI Response Note should not appear in default Notes query")
    try expect(freshness == .dirty, "reversing the AI Operation should mark User Search Derived Index dirty")
}

func aiCannotReverseSavedAIResponseOperation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let saved = try savedAIResponse(from: runtime.execute(.saveAIResponse(.init(
        response: "Saved response body.",
        destination: .newNote(title: "Saved AI Response")
    ))))
    guard case .note(let note) = saved.destination, let operation = saved.aiOperation else {
        throw BehaviorTestFailure(description: "expected Saved AI Response new Note and AI Operation")
    }

    try expectRuntimeError(.runtimeCommandNotAllowedForAI) {
        _ = try runtime.execute(.reverseAIOperation(.init(operationID: operation.id)), source: .ai)
    }

    let activeNotes = try notes(from: runtime.query(.notes))

    switch try runtime.query(.note(note.id)) {
    case .note(let storedNote):
        try expect(storedNote == note, "AI-rejected reverse should leave the created Note unchanged")
        try expect(storedNote?.isTrashed == false, "AI-rejected reverse should not move the created Note to Trash")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(activeNotes.contains(note), "AI-rejected reverse should leave the created Note active")
}

func savingAIResponseToDraftChangeCreatesDraftWithoutMutatingNoteBody() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let note = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Draft Target",
        body: "Original body.",
        creationProvenance: .userCreated
    ))))
    let response = "Draft response body."

    let saved = try savedAIResponse(from: runtime.execute(.saveAIResponse(.init(
        response: response,
        destination: .draftChange(noteID: note.id)
    ))))

    guard case .draftChange(let draftChange) = saved.destination else {
        throw BehaviorTestFailure(description: "expected Saved AI Response Draft Change destination")
    }

    switch try runtime.query(.note(note.id)) {
    case .note(let storedNote):
        try expect(storedNote?.body == "Original body.", "Draft Change destination should not mutate Note Body")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(saved.id == .init("saved-ai-response-1"), "Draft Change Saved AI Response should expose a local ID")
    try expect(draftChange == DraftChange(
        id: .init("draft-change-1"),
        noteID: note.id,
        body: response
    ), "Draft Change destination should create a minimal draft record")
    try expect(saved.aiOperation == nil, "Draft Change destination should leave full draft AI Operation behavior to a later issue")
}

func responseOnlySummaryReturnsTextWithoutDurableState() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        sourceNoteIDs: [source.id],
        destination: .responseOnly
    ))
    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let progress = try aiProgressState(from: runtime.query(.aiProgressState))

    try expect(result == SummaryResult(
        summary: "Summary Output:\nBasalt Field Notes: Basalt forms from rapid cooling.",
        citations: [
            SourceCitation(noteID: source.id, noteFragmentID: "note-body")
        ],
        output: .responseOnly
    ), "response-only Summary Output should return deterministic text with Source Citations")
    try expect(activeNotes == [source], "response-only Summary Output should not create or mutate Notes")
    try expect(operations.isEmpty, "response-only Summary Output should not create an AI Operation")
    try expect(progress == .idle, "completed response-only Summary Output should leave AI Progress State idle")
    try expectRuntimeError(.draftChangeNotFound(.init("draft-change-1"))) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: .init("draft-change-1"))))
    }
}

func summaryRoutedToDraftChangeCreatesDraftWithoutMutatingTargetNote() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Summary Target",
        body: "Original target body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        sourceNoteIDs: [source.id],
        destination: .draftChange(noteID: target.id)
    ))
    guard case .draftChange(let draftChange) = result.output else {
        throw BehaviorTestFailure(description: "expected Summary Output to create a Draft Change")
    }

    let storedTarget = try note(from: runtime.query(.note(target.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(result.summary == "Summary Output:\nBasalt Field Notes: Basalt forms from rapid cooling.", "Draft Change Summary Output should expose summary text")
    try expect(draftChange == DraftChange(
        id: .init("draft-change-1"),
        noteID: target.id,
        body: result.summary,
        localModelProfileID: .init("model-a")
    ), "Draft Change Summary Output should create a reviewable draft with model provenance")
    try expect(storedTarget == target, "Draft Change Summary Output should not mutate the target Note before acceptance")
    try expect(operations.isEmpty, "Draft Change Summary Output should not create an AI Operation before acceptance")
}

func acceptingSummaryDraftChangeAppliesContentWithReversibleAIOperation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))
    let target = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Summary Target",
        body: "Original target body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        sourceNoteIDs: [source.id],
        destination: .draftChange(noteID: target.id)
    ))
    guard case .draftChange(let draftChange) = result.output else {
        throw BehaviorTestFailure(description: "expected Summary Output to create a Draft Change")
    }

    let operation = try acceptedDraftChangeOperation(from: runtime.execute(.acceptDraftChange(.init(draftChangeID: draftChange.id))))
    let updated = try note(from: runtime.query(.note(target.id)))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(updated?.body == result.summary, "accepted Summary Draft Change should apply summary text to Note Body")
    try expect(operation.localModelProfileID == .init("model-a"), "accepted Summary Draft Change operation should record the Local Model Profile")
    try expect(operation.changes == [
        AIChange(noteID: target.id, previousNote: target, newNote: updated)
    ], "accepted Summary Draft Change should create a reversible note-level AI Change")
    try expect(operations == [operation], "accepted Summary Draft Change should commit a durable AI Operation")
}

func summaryRoutedToNewNoteWithDirectPermissionCreatesReversibleAIOperation() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.runIndexingJobs(.init()))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    let result = try runtime.summarize(.init(
        sessionID: sessionID,
        sourceNoteIDs: [source.id],
        destination: .newNote(title: "Basalt Summary")
    ))
    guard case .newNote(let created, let operation) = result.output else {
        throw BehaviorTestFailure(description: "expected Summary Output to create a new Note")
    }

    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let freshness = try indexFreshness(from: runtime.query(.indexFreshness(.userSearch)))

    try expect(created.title == "Basalt Summary", "new Note Summary Output should use the requested Note Title")
    try expect(created.body == result.summary, "new Note Summary Output should store summary text as Note Body")
    try expect(created.creationProvenance == .aiCreated, "new Note Summary Output should record AI Creation Provenance")
    try expect(operation.localModelProfileID == .init("model-a"), "new Note Summary Output operation should record the Local Model Profile")
    try expect(operation.changes == [
        AIChange(noteID: created.id, previousNote: nil, newNote: created)
    ], "new Note Summary Output should record the created Note as an AI Change")
    try expect(activeNotes == [source, created], "new Note Summary Output should add the created Note to active Notes")
    try expect(operations == [operation], "new Note Summary Output should commit a durable AI Operation")
    try expect(freshness == .dirty, "new Note Summary Output should mark User Search Derived Index dirty")

    let reversed = try reversedAIOperation(from: runtime.execute(.reverseAIOperation(.init(operationID: operation.id))))
    let activeAfterReverse = try notes(from: runtime.query(.notes))

    switch try runtime.query(.note(created.id)) {
    case .note(let storedCreated):
        try expect(storedCreated?.isTrashed == true, "reversing new Note Summary Output should move the created Note out of the active corpus")
    default:
        throw BehaviorTestFailure(description: "expected a single Note query result")
    }

    try expect(reversed.isReversed, "reversing new Note Summary Output should mark the AI Operation reversed")
    try expect(activeAfterReverse == [source], "reversing new Note Summary Output should remove the created Note from active Notes")
}

func reversingNewNoteSummaryRemovesGeneratedWikilinkPlaceholderAndGraphSideEffects() throws {
    let summary = "Summary links to [[AI Summary Placeholder]]."
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(summary: summary))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .directEdit
    ))))

    let result = try runtime.summarize(.init(
        sessionID: sessionID,
        sourceNoteIDs: [source.id],
        destination: .newNote(title: "Basalt Summary")
    ))
    guard case .newNote(let created, let operation) = result.output else {
        throw BehaviorTestFailure(description: "expected Summary Output to create a new Note")
    }
    guard let placeholder = try notes(from: runtime.query(.notes)).first(where: { $0.title == "AI Summary Placeholder" }) else {
        throw BehaviorTestFailure(description: "expected generated Summary Output Wikilink to create a Placeholder Note")
    }

    let links = try explicitLinks(from: runtime.query(.explicitLinks(created.id)))
    let placeholderBacklinks = try backlinks(from: runtime.query(.backlinks(placeholder.id)))

    try expect(created.body == summary, "new Note Summary Output should store generated summary text")
    try expect(placeholder.isPlaceholder, "generated Summary Output Wikilink should create a Placeholder Note")
    try expect(operation.createdPlaceholderNoteIDs == [placeholder.id], "new Note Summary Output operation should remember generated Placeholder Notes")
    try expect(links == [
        ExplicitLink(
            sourceNoteID: created.id,
            targetNoteID: placeholder.id,
            snippet: summary
        )
    ], "new Note Summary Output should create Explicit Links from generated Wikilinks")
    try expect(placeholderBacklinks == [
        Backlink(
            sourceNoteID: created.id,
            sourceNoteTitle: created.title,
            targetNoteID: placeholder.id,
            snippet: summary
        )
    ], "generated Placeholder Note should expose backlink from Summary Output Note")

    _ = try reversedAIOperation(from: runtime.execute(.reverseAIOperation(.init(operationID: operation.id))))
    let activeAfterReverse = try notes(from: runtime.query(.notes))
    let graphAfterReverse = try trustedGraph(from: runtime.query(.trustedGraph))
    let linksAfterReverse = try explicitLinks(from: runtime.query(.explicitLinks(created.id)))
    let backlinksAfterReverse = try backlinks(from: runtime.query(.backlinks(placeholder.id)))
    let storedCreated = try note(from: runtime.query(.note(created.id)))
    let storedPlaceholder = try note(from: runtime.query(.note(placeholder.id)))

    try expect(activeAfterReverse == [source], "reversing new Note Summary Output should remove generated Note and Placeholder from active Notes")
    try expect(graphAfterReverse == TrustedGraph(
        nodes: [
            TrustedGraphNode(noteID: source.id, title: source.title, isPlaceholder: false)
        ],
        edges: []
    ), "reversing new Note Summary Output should remove generated graph side effects")
    try expect(linksAfterReverse.isEmpty, "reversing new Note Summary Output should remove generated Explicit Links")
    try expect(backlinksAfterReverse.isEmpty, "reversing new Note Summary Output should remove generated Placeholder Backlinks")
    try expect(storedCreated?.isTrashed == true, "reversing new Note Summary Output should move generated Note to Trash")
    try expect(storedPlaceholder?.isTrashed == true, "reversing new Note Summary Output should move generated Placeholder Note to Trash")
}

func newNoteSummaryRequiresDirectEditingPermission() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    try expectRuntimeError(.aiWriteDestinationRequired) {
        _ = try runtime.summarize(.init(
            sessionID: sessionID,
            sourceNoteIDs: [source.id],
            destination: .newNote(title: "Blocked Summary")
        ))
    }

    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let progress = try aiProgressState(from: runtime.query(.aiProgressState))

    try expect(activeNotes == [source], "new Note Summary Output without Direct Edit permission should create no Note")
    try expect(operations.isEmpty, "new Note Summary Output without Direct Edit permission should create no AI Operation")
    try expect(progress == .idle, "rejected new Note Summary Output should leave AI Progress State idle")
}

func blockedNewNoteSummaryDoesNotInvokeAIAdapter() throws {
    var adapterCalls = 0
    let runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(onSummaryProgress: { _ in
        adapterCalls += 1
        throw RuntimeError.aiOperationCommitFailed
    }))
    let sessionID = AISessionID("ai-session-1")
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Private Source",
        body: "Private source body.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))
    _ = try runtime.execute(.setAIEditingPermission(.init(permission: .init(
        sessionID: sessionID,
        mode: .draftChange
    ))))

    try expectRuntimeError(.aiWriteDestinationRequired) {
        _ = try runtime.summarize(.init(
            sessionID: sessionID,
            sourceNoteIDs: [source.id],
            destination: .newNote(title: "Blocked Summary")
        ))
    }

    let progress = try aiProgressState(from: runtime.query(.aiProgressState))
    let operations = try aiOperations(from: runtime.query(.aiOperations))

    try expect(adapterCalls == 0, "blocked new Note Summary Output should not feed sources into the AI adapter")
    try expect(progress == .idle, "blocked new Note Summary Output should not enter AI Progress States")
    try expect(operations.isEmpty, "blocked new Note Summary Output should create no AI Operation")
}

func summaryFailsFastWhenAIIsUnavailableWithoutDurableState() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    try expectRuntimeError(.aiUnavailable(.noUsableLocalModelProfile)) {
        _ = try runtime.summarize(.init(
            sessionID: .init("ai-session-1"),
            sourceNoteIDs: [source.id],
            destination: .draftChange(noteID: source.id)
        ))
    }

    let unavailable = try aiUnavailableState(from: runtime.query(.aiUnavailableState))
    let activeNotes = try notes(from: runtime.query(.notes))
    let operations = try aiOperations(from: runtime.query(.aiOperations))
    let progress = try aiProgressState(from: runtime.query(.aiProgressState))

    try expect(unavailable == .noUsableLocalModelProfile, "unavailable Summary Output should expose AI Unavailable State")
    try expect(activeNotes == [source], "unavailable Summary Output should not create or mutate Notes")
    try expect(operations.isEmpty, "unavailable Summary Output should not create an AI Operation")
    try expect(progress == .idle, "unavailable Summary Output should leave AI Progress State idle")
    try expectRuntimeError(.draftChangeNotFound(.init("draft-change-1"))) {
        _ = try runtime.execute(.acceptDraftChange(.init(draftChangeID: .init("draft-change-1"))))
    }
}

func summaryOverSelectedNoteSetIncludesEachSourceDeterministically() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let basalt = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))
    let granite = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Granite Field Notes",
        body: "Granite cools slowly underground.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        sourceNoteIDs: [granite.id, basalt.id],
        destination: .responseOnly
    ))

    try expect(result == SummaryResult(
        summary: """
        Summary Output:
        Granite Field Notes: Granite cools slowly underground.
        Basalt Field Notes: Basalt forms from rapid cooling.
        """,
        citations: [
            SourceCitation(noteID: granite.id, noteFragmentID: "note-body"),
            SourceCitation(noteID: basalt.id, noteFragmentID: "note-body")
        ],
        output: .responseOnly
    ), "Summary Output over a selected Note set should include both sources in selected order")
}

func summaryCanUseRetrievedNotesFromPrompt() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()
    let detail = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Detail",
        body: "Basalt is volcanic rock.",
        creationProvenance: .userCreated
    ))))
    let linked = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Field Context",
        body: "Linked context.",
        creationProvenance: .userCreated
    ))))
    let daily = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "Basalt observations connect to [[Field Context]].",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.runIndexingJobs(.init()))
    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let result = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        prompt: "basalt",
        destination: .responseOnly
    ))

    try expect(result == SummaryResult(
        summary: """
        Summary Output:
        Basalt Detail: Basalt is volcanic rock.
        Daily Note: Basalt observations connect to [[Field Context]].
        Field Context: Linked context.
        """,
        citations: [
            SourceCitation(noteID: detail.id, noteFragmentID: "note-body"),
            SourceCitation(noteID: daily.id, noteFragmentID: "note-body"),
            SourceCitation(noteID: linked.id, noteFragmentID: "note-body")
        ],
        output: .responseOnly
    ), "Summary Output should summarize retrieved Notes with citations in retrieval order")
}

func summaryExposesProgressStateTransitionsDuringWorkflow() throws {
    var runtime: OnDeviceKnowledgeRuntime!
    var observed: [AIProgressState] = []
    runtime = RuntimeCoreHarness.makeInMemory(aiRuntimeAdapter: FakeAIRuntimeAdapter(onSummaryProgress: { _ in
        observed.append(try aiProgressState(from: runtime.query(.aiProgressState)))
    }))
    let source = try createdNote(from: runtime.execute(.createNote(.init(
        title: "Basalt Field Notes",
        body: "Basalt forms from rapid cooling.",
        creationProvenance: .userCreated
    ))))

    _ = try runtime.execute(.recordLocalModelProfile(.init(profile: .init(
        id: .init("model-a"),
        name: "QVAC Tiny"
    ))))

    let before = try aiProgressState(from: runtime.query(.aiProgressState))
    _ = try runtime.summarize(.init(
        sessionID: .init("ai-session-1"),
        sourceNoteIDs: [source.id],
        destination: .responseOnly
    ))
    let after = try aiProgressState(from: runtime.query(.aiProgressState))

    try expect(before == .idle, "Summary Output should start from idle AI Progress State")
    try expect(observed == [.loadingModel, .generating], "Summary Output should expose loading and generating AI Progress States during workflow")
    try expect(after == .idle, "Summary Output should return AI Progress State to idle after completion")
}

func aiProgressStateRepresentsIdleLoadingAndGeneratingPhases() throws {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let currentState = try aiProgressState(from: runtime.query(.aiProgressState))
    let futureWorkflowStates: [AIProgressState] = [.idle, .loadingModel, .generating]

    try expect(currentState == .idle, "new runtime should start with idle AI Progress State")
    try expect(futureWorkflowStates[1] == .loadingModel, "AI Progress State should represent model loading")
    try expect(futureWorkflowStates[2] == .generating, "AI Progress State should represent generation")
}

func qvacAdapterProtocolRoundTripsRequestIDsAndOperations() throws {
    let request = QVACAdapterRequest(
        id: .init("request-1"),
        operation: .answer(.init(
            prompt: "What matters?",
            mode: .noteGrounded,
            context: [
                .init(noteID: "note-1", title: "Field Notes", body: "Basalt cools quickly.")
            ]
        ))
    )

    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(QVACAdapterRequest.self, from: encoded)

    try expect(decoded.id == .init("request-1"), "QVAC adapter request ID should survive Codable round-trip")
    try expect(decoded.operation == request.operation, "QVAC adapter operation should survive Codable round-trip")
}

final class CapturingEmbeddedQVACHostStatusBridge: ProductionIOSEmbeddedQVACHostStatusBridge, @unchecked Sendable {
    private(set) var receivedRequests: [ProductionIOSEmbeddedQVACHostStatusRequest] = []
    let response: ProductionIOSEmbeddedQVACHostStatusResponse

    init(response: ProductionIOSEmbeddedQVACHostStatusResponse) {
        self.response = response
    }

    func status(for request: ProductionIOSEmbeddedQVACHostStatusRequest) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        receivedRequests.append(request)
        return response
    }
}

func productionIOSEmbeddedQVACHostStatusBridgeReturnsMatchingRequestScopedResponse() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-1"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )
    let response = ProductionIOSEmbeddedQVACHostStatusResponse(
        requestID: .init("status-1"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter,
        status: .ready,
        diagnostic: .embeddedHostReady,
        lifecycleRisks: [
            .hostLifecycle,
            .requestCancellation,
            .localModelFileOwnership,
            .memoryPressure,
            .appBackgrounding
        ]
    )
    let bridge = CapturingEmbeddedQVACHostStatusBridge(response: response)

    let actual = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)

    try expect(bridge.receivedRequests == [request], "embedded QVAC host status bridge should receive the request-scoped status request")
    try expect(actual == response, "embedded QVAC host status bridge should return the matching content-free status response")
}

func productionIOSEmbeddedQVACHostStatusBridgeRejectsMismatchedRequestIDResponse() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-1"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )
    let response = ProductionIOSEmbeddedQVACHostStatusResponse(
        requestID: .init("status-other"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter,
        status: .ready,
        diagnostic: .embeddedHostReady,
        lifecycleRisks: [.hostLifecycle]
    )
    let bridge = CapturingEmbeddedQVACHostStatusBridge(response: response)

    try await expectEmbeddedQVACHostStatusError(
        .unexpectedResponseRequestID(expected: .init("status-1"), actual: .init("status-other"))
    ) {
        _ = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)
    }
}

func productionIOSEmbeddedQVACHostNotLinkedBridgeReturnsContentFreeUnavailableStatus() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-2"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )

    let response = try await ProductionIOSEmbeddedQVACHost.status(
        for: request,
        using: ProductionIOSEmbeddedQVACHostNotLinkedStatusBridge()
    )

    try expect(response.requestID == .init("status-2"), "not-linked status bridge should preserve the request ID")
    try expect(response.hostKind == .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter, "not-linked status bridge should preserve the host kind")
    try expect(response.status == .notLinked, "not-linked status bridge should not fake readiness")
    try expect(response.diagnosticCode == "embedded-qvac-host-not-linked", "not-linked status bridge should return a content-free diagnostic code")
    try expect(response.diagnosticMessage == "Embedded QVAC host is not linked.", "not-linked status bridge should return a content-free diagnostic message")
    try expect(
        response.lifecycleRisks == ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks,
        "not-linked status bridge should report the production lifecycle risks"
    )
}

func productionIOSEmbeddedQVACHostLinkedBridgeReturnsStartingStatusWithoutNotLinked() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-linked-starting"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )
    let bridge = ProductionIOSEmbeddedQVACHostLinkedStatusBridge(
        startupStatusProvider: { .starting }
    )

    let response = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)

    try expect(response.requestID == .init("status-linked-starting"), "linked embedded host bridge should preserve request ID")
    try expect(response.hostKind == .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter, "linked embedded host bridge should preserve host kind")
    try expect(response.status == .starting, "linked embedded host bridge should report the host startup state")
    try expect(response.status != .notLinked, "linked embedded host bridge should not report not-linked")
    try expect(response.diagnostic == .embeddedHostStarting, "linked embedded host bridge should use a content-free starting diagnostic")
    try expect(
        response.lifecycleRisks == ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks,
        "linked embedded host bridge should report the production lifecycle risks"
    )
}

struct EmbeddedQVACHostStartupFailure: Error {}

final class CapturingEmbeddedQVACHostStatusResponseProvider: @unchecked Sendable {
    private(set) var receivedRequests: [ProductionIOSEmbeddedQVACHostStatusRequest] = []

    func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        receivedRequests.append(request)
        return ProductionIOSEmbeddedQVACHostStatusResponse(
            requestID: request.id,
            hostKind: request.hostKind,
            status: .ready,
            diagnostic: .embeddedHostReady,
            lifecycleRisks: ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks
        )
    }
}

func productionIOSEmbeddedQVACHostLinkedBridgeSendsRequestToHostResponseProvider() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-linked-host-response"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )
    let provider = CapturingEmbeddedQVACHostStatusResponseProvider()
    let bridge = ProductionIOSEmbeddedQVACHostLinkedStatusBridge(
        statusResponseProvider: provider.status(for:)
    )

    let response = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)

    try expect(provider.receivedRequests == [request], "linked embedded host bridge should send the request-scoped status request to the host response provider")
    try expect(response.requestID == request.id, "linked embedded host bridge should return the host response request ID")
    try expect(response.status == .ready, "linked embedded host bridge should return the host response status")
}

func productionIOSEmbeddedQVACHostLinkedBridgeMapsStartupFailureToUnavailable() async throws {
    let request = ProductionIOSEmbeddedQVACHostStatusRequest(
        id: .init("status-linked-unavailable"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
    )
    let bridge = ProductionIOSEmbeddedQVACHostLinkedStatusBridge(
        startupStatusProvider: { throw EmbeddedQVACHostStartupFailure() }
    )

    let response = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)

    try expect(response.requestID == .init("status-linked-unavailable"), "failed linked embedded host startup should preserve request ID")
    try expect(response.hostKind == .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter, "failed linked embedded host startup should preserve host kind")
    try expect(response.status == .unavailable, "failed linked embedded host startup should report unavailable")
    try expect(response.status != .notLinked, "failed linked embedded host startup should not fall back to not-linked")
    try expect(response.diagnosticCode == "embedded-qvac-host-unavailable", "failed linked embedded host startup should return content-free diagnostic code")
    try expect(response.diagnosticMessage == "Embedded QVAC host is unavailable.", "failed linked embedded host startup should return content-free diagnostic message")
}

func productionIOSEmbeddedQVACHostStatusResponseCodableDerivesDiagnosticCodeAndMessage() throws {
    let response = ProductionIOSEmbeddedQVACHostStatusResponse(
        requestID: .init("status-3"),
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter,
        status: .unavailable,
        diagnostic: .embeddedHostUnavailable,
        lifecycleRisks: [.hostLifecycle, .memoryPressure]
    )

    let encoded = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(ProductionIOSEmbeddedQVACHostStatusResponse.self, from: encoded)

    try expect(decoded.diagnostic == .embeddedHostUnavailable, "embedded host status response should preserve the typed diagnostic through Codable")
    try expect(decoded.diagnosticCode == "embedded-qvac-host-unavailable", "embedded host status response should derive diagnostic code from the typed diagnostic")
    try expect(decoded.diagnosticMessage == "Embedded QVAC host is unavailable.", "embedded host status response should derive diagnostic message from the typed diagnostic")
}

func productionIOSEmbeddedQVACHostStatusResponseIgnoresDecodedDiagnosticCodeAndMessageFields() throws {
    let payload = """
    {
      "requestID": { "rawValue": "status-4" },
      "hostKind": "physicalIOSEmbeddedExpoBehindAIRuntimeAdapter",
      "status": "unavailable",
      "diagnostic": "embedded-qvac-host-unavailable",
      "diagnosticCode": "content-bearing-code",
      "diagnosticMessage": "content-bearing message",
      "lifecycleRisks": ["hostLifecycle"]
    }
    """

    let decoded = try JSONDecoder().decode(
        ProductionIOSEmbeddedQVACHostStatusResponse.self,
        from: Data(payload.utf8)
    )

    try expect(decoded.diagnostic == .embeddedHostUnavailable, "embedded host status response should decode the typed diagnostic")
    try expect(decoded.diagnosticCode == "embedded-qvac-host-unavailable", "decoded diagnostic code should ignore arbitrary payload fields")
    try expect(decoded.diagnosticMessage == "Embedded QVAC host is unavailable.", "decoded diagnostic message should ignore arbitrary payload fields")
}

func productionIOSQVACAdapterContractDefinesPhysicalEmbeddedExpoHost() throws {
    let contract = ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter

    try expect(
        contract.hostKind == .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter,
        "production iOS QVAC adapter contract should define embedded Expo behind AIRuntimeAdapter on a physical iOS device"
    )
    try expect(
        contract.macHostedDevelopmentAdapterRole == .developmentOnlyDistinctFromProduction,
        "Mac-hosted QVAC adapter should remain development-only and distinct from production iOS"
    )
}

func productionIOSQVACAdapterContractDefinesRequestScopedPayloadsAndEvents() throws {
    let contract = ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter

    try expect(
        contract.payloadAuthority == .swiftRequestScopedPromptContextAndModel,
        "Swift runtime should authorize only request-scoped prompt, selected context, and model payloads"
    )
    try expect(
        contract.bridgeEvents == [.progress, .token, .completion, .cancel, .error],
        "production iOS QVAC bridge events should cover progress, token, completion, cancel, and error"
    )
}

func productionIOSQVACAdapterContractForbidsDelegatedRuntimeAuthorityAndHostedDependencies() throws {
    let contract = ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter

    try expect(
        contract.forbiddenResponsibilities == [
            .reactNativeOrExpoUI,
            .notePersistence,
            .graphTraversal,
            .citationAuthority,
            .wholeCorpusNoteAccess
        ],
        "production iOS QVAC bridge should forbid React Native UI, persistence, graph traversal, citation authority, and whole-corpus note access"
    )
    try expect(
        contract.forbiddenDependencies == [
            .cloudBackendOrInference,
            .hostedExpoService,
            .nodeSidecar,
            .emulatorOnlyAssumption
        ],
        "production iOS QVAC bridge should forbid cloud inference, hosted Expo services, Node sidecars, and emulator-only assumptions"
    )
}

func productionIOSQVACAdapterContractDocumentsLifecycleRisksAndPhysicalDeviceValidation() throws {
    let contract = ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter

    try expect(
        contract.lifecycleRisks == [
            .hostLifecycle,
            .requestCancellation,
            .localModelFileOwnership,
            .memoryPressure,
            .appBackgrounding
        ],
        "production iOS QVAC contract should document lifecycle, cancellation, model file, memory, and backgrounding risks"
    )
    try expect(
        contract.validationRequirement == .physicalIOSDeviceRequired,
        "production iOS QVAC contract should require physical iOS device validation"
    )
}

func productionIOSQVACAdapterContractKeepsExpoLocalAndLimitedToSelectedContext() throws {
    let contract = ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter

    try expect(
        contract.executionLocality == .bundledLocalOnDevice,
        "embedded Expo QVAC adapter should run locally inside the iOS app bundle on device"
    )
    try expect(
        contract.contextScope == .swiftSelectedContextOnly,
        "embedded Expo QVAC adapter should receive only Swift-selected request context, not whole-corpus or graph access"
    )
    try expect(
        contract.citationAuthority == .swiftRuntime,
        "Swift runtime should remain authoritative for Source Citations"
    )
}

func qvacPhysicalDeviceSmokeEnvironment(
    executionTarget: QVACPhysicalDeviceSmokeExecutionTarget = .physicalDevice,
    majorIOSVersion: Int = 17,
    requiresLocalOnlyExecution: Bool = true,
    requiresAppStorePublication: Bool = false,
    hostPath: QVACPhysicalDeviceSmokeHostPath = .embeddedExpoBareRuntime
) -> QVACPhysicalDeviceSmokeEnvironment {
    QVACPhysicalDeviceSmokeEnvironment(
        platform: .iOS,
        executionTarget: executionTarget,
        majorIOSVersion: majorIOSVersion,
        requiresLocalOnlyExecution: requiresLocalOnlyExecution,
        requiresAppStorePublication: requiresAppStorePublication,
        hostPath: hostPath
    )
}

func qvacPhysicalDeviceSmokeModelProfile() -> QVACPhysicalDeviceSmokeModelProfile {
    QVACPhysicalDeviceSmokeModelProfile(
        identifier: "LLAMA_3_2_1B_INST_Q4_0",
        name: "Llama 3.2 1B Instruct Q4_0",
        source: "QVAC quickstart constant"
    )
}

func qvacPhysicalDeviceSmokePlanRejectsSimulatorAsValidationEnvironment() throws {
    let simulatorEnvironment = qvacPhysicalDeviceSmokeEnvironment(executionTarget: .simulator)

    let validation = QVACPhysicalDeviceSmokePlan.validatePrerequisites(simulatorEnvironment)

    try expect(
        validation.status == .blockedPendingPhysicalDeviceRun,
        "simulator validation should remain blocked pending a physical iPhone run"
    )
    try expect(
        validation.rejections.contains(.physicalIOSDeviceRequired),
        "simulator validation should reject non-physical execution targets"
    )
}

func qvacPhysicalDeviceSmokePlanRejectsIOSVersionsBelowSeventeen() throws {
    let oldIOSEnvironment = qvacPhysicalDeviceSmokeEnvironment(majorIOSVersion: 16)

    let validation = QVACPhysicalDeviceSmokePlan.validatePrerequisites(oldIOSEnvironment)

    try expect(
        validation.status == .blockedPendingPhysicalDeviceRun,
        "iOS versions below 17 should remain blocked for QVAC physical-device smoke validation"
    )
    try expect(
        validation.rejections.contains(.minimumIOS17Required),
        "iOS versions below 17 should be rejected"
    )
}

func qvacPhysicalDeviceSmokePlanRequiresLocalOnlyExecution() throws {
    let cloudPermittedEnvironment = qvacPhysicalDeviceSmokeEnvironment(requiresLocalOnlyExecution: false)

    let validation = QVACPhysicalDeviceSmokePlan.validatePrerequisites(cloudPermittedEnvironment)

    try expect(
        validation.status == .blockedPendingPhysicalDeviceRun,
        "QVAC smoke validation should block when local-only execution is not required"
    )
    try expect(
        validation.rejections.contains(.localOnlyExecutionRequired),
        "QVAC smoke validation should reject cloud-capable or hosted inference smoke paths"
    )
}

func qvacPhysicalDeviceSmokePlanDoesNotRequireAppStorePublication() throws {
    let appStoreRequiredEnvironment = qvacPhysicalDeviceSmokeEnvironment(requiresAppStorePublication: true)

    let validation = QVACPhysicalDeviceSmokePlan.validatePrerequisites(appStoreRequiredEnvironment)

    try expect(
        validation.status == .blockedPendingPhysicalDeviceRun,
        "QVAC smoke validation should block paths that require App Store publication"
    )
    try expect(
        validation.rejections.contains(.developmentInstallMustNotRequireAppStorePublication),
        "QVAC smoke validation should allow Xcode or local development install without App Store publication"
    )
}

func qvacPhysicalDeviceSmokeResultRecordsValidatedLocalModelResponseAndHostPath() throws {
    let physicalDeviceEnvironment = qvacPhysicalDeviceSmokeEnvironment()
    let modelProfile = qvacPhysicalDeviceSmokeModelProfile()
    let generatedText = "Local model generated one response."

    let result = QVACPhysicalDeviceSmokePlan.recordResult(
        environment: physicalDeviceEnvironment,
        modelProfile: modelProfile,
        generatedText: generatedText,
        offlineRepeatabilityChecked: true
    )

    try expect(result.status == .validatedOnPhysicalDevice, "valid physical-device smoke result should be marked validated")
    try expect(result.hostPath == .embeddedExpoBareRuntime, "smoke result should record the host path selected for Issue 14")
    try expect(result.modelProfile == modelProfile, "smoke result should record the loaded or discovered model profile")
    try expect(result.generatedTextNonEmpty, "smoke result should record that a non-empty generated response was observed")
    try expect(result.offlineRepeatabilityChecked, "smoke result should record that offline repeatability was checked after model setup")
    try expect(result.rejections.isEmpty, "valid physical-device smoke result should not carry prerequisite rejections")

    let encodedResult = String(data: try JSONEncoder().encode(result), encoding: .utf8)!
    try expect(
        !encodedResult.contains(generatedText),
        "public smoke result payload should not retain or encode full generated response text"
    )
    try expect(
        encodedResult.contains("\"generatedTextNonEmpty\":true"),
        "public smoke result payload should encode only a content-free generated response signal"
    )
}

func qvacPhysicalDeviceSmokeResultRejectsEmptyGeneratedText() throws {
    let result = QVACPhysicalDeviceSmokePlan.recordResult(
        environment: qvacPhysicalDeviceSmokeEnvironment(),
        modelProfile: qvacPhysicalDeviceSmokeModelProfile(),
        generatedText: " \n\t ",
        offlineRepeatabilityChecked: true
    )

    try expect(
        result.status == .blockedPendingPhysicalDeviceRun,
        "empty generated response should keep the physical-device smoke result blocked"
    )
    try expect(
        result.rejections.contains(.nonEmptyGeneratedTextRequired),
        "empty generated response should be rejected"
    )
    try expect(
        !result.generatedTextNonEmpty,
        "empty generated response should record a false content-free generated response signal"
    )
}

func qvacPhysicalDeviceSmokeResultRequiresOfflineRepeatabilityCheck() throws {
    let result = QVACPhysicalDeviceSmokePlan.recordResult(
        environment: qvacPhysicalDeviceSmokeEnvironment(),
        modelProfile: qvacPhysicalDeviceSmokeModelProfile(),
        generatedText: "Local model generated one response.",
        offlineRepeatabilityChecked: false
    )

    try expect(
        result.status == .blockedPendingPhysicalDeviceRun,
        "missing offline repeatability check should keep the physical-device smoke result blocked"
    )
    try expect(
        result.rejections.contains(.offlineRepeatabilityCheckRequired),
        "missing offline repeatability check should be rejected"
    )
}

func qvacPhysicalDeviceSmokeRunbookPreservesHITLChecklist() throws {
    let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let runbookURL = repositoryRoot.appendingPathComponent("docs/qvac-physical-device-smoke-test.md")
    let issueURL = repositoryRoot.appendingPathComponent(".scratch/qvac-notes-v1-frontend-runtime-integration/issues/13-prove-qvac-sdk-local-model-on-physical-iphone.md")

    let runbook = try String(contentsOf: runbookURL, encoding: .utf8)
    let issue = try String(contentsOf: issueURL, encoding: .utf8)

    let requiredRunbookTerms = [
        "no App Store publication is needed",
        "install/run from Xcode/local development install",
        "physical iPhone",
        "iOS 17+",
        "arm64/Metal",
        "Simulator/emulators are not valid",
        "@qvac/sdk",
        "Expo >= 54",
        "react-native-bare-kit",
        "bare-pack",
        "expo-file-system",
        "expo-build-properties",
        "expo-device",
        "@qvac/sdk/expo-plugin",
        "npx expo prebuild",
        "npx expo run:ios --device",
        "LLAMA_3_2_1B_INST_Q4_0",
        "completion",
        "unload model",
        "Airplane Mode",
        "must not use cloud inference",
        "no note text, prompts, responses, citations, filenames, AI history",
        "embeddedExpoBareRuntime",
        "nativeBinding",
        "otherApprovedLocalOnlyHost",
        "unblocks Issue 14 only after physical-device validation"
    ]

    for term in requiredRunbookTerms {
        try expect(runbook.contains(term), "QVAC physical-device smoke runbook should include required checklist term: \(term)")
    }

    try expect(
        runbook.contains("generatedTextNonEmpty: true"),
        "QVAC physical-device smoke runbook report should ask only for a content-free generated response signal"
    )
    try expect(
        !runbook.contains("\ngeneratedText:"),
        "QVAC physical-device smoke runbook report should not ask for generated response text"
    )

    try expect(
        issue.contains("Code-side smoke contract/docs exist"),
        "Issue 13 status note should say code-side smoke contract/docs exist"
    )
    try expect(
        issue.contains("HITL physical validation completed on 2026-06-19"),
        "Issue 13 status note should say physical smoke validation completed on 2026-06-19"
    )
    try expect(
        issue.contains("Physical smoke validation is complete"),
        "Issue 13 status note should record completed physical smoke validation"
    )
    try expect(
        issue.contains("generatedTextNonEmpty: true"),
        "Issue 13 status note should record only a content-free generated response signal"
    )
    try expect(
        !issue.contains("\ngeneratedText:"),
        "Issue 13 status note should not include generated response text"
    )
    try expect(
        !issue.contains("\nprompt:"),
        "Issue 13 status note should not include prompts"
    )
    try expect(
        !issue.contains("\nnoteContent:"),
        "Issue 13 status note should not include note content"
    )
}

struct ScriptedLocalQVACAdapterTransport: LocalQVACAdapterTransport {
    let handler: (QVACAdapterRequest) throws -> [QVACAdapterResponse]

    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] {
        try handler(request)
    }
}

final class CapturingLocalQVACAdapterTransport: LocalQVACAdapterTransport {
    private(set) var sentRequests: [QVACAdapterRequest] = []

    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] {
        sentRequests.append(request)
        return [
            .init(requestID: request.id, event: .completed(.text("ok")))
        ]
    }
}

func shellSingleQuoted(_ string: String) -> String {
    "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
}

func jsonLine(_ response: QVACAdapterResponse) throws -> String {
    String(data: try JSONEncoder().encode(response), encoding: .utf8)!
}

func expectQVACDevelopmentAdapterError(_ expected: QVACDevelopmentAdapterError, _ work: () throws -> Void) throws {
    do {
        try work()
    } catch let error as QVACDevelopmentAdapterError {
        try expect(error == expected, "expected \(expected), got \(error)")
        return
    }

    throw BehaviorTestFailure(description: "expected \(expected)")
}

func qvacDevelopmentAdapterAggregatesStreamingTokensAndProgress() throws {
    var capturedRequests: [QVACAdapterRequest] = []
    var observedProgress: [AIProgressState] = []
    let transport = ScriptedLocalQVACAdapterTransport { request in
        capturedRequests.append(request)
        return [
            .init(requestID: request.id, event: .progress(.loadingModel)),
            .init(requestID: request.id, event: .progress(.generating)),
            .init(requestID: request.id, event: .token("Summary")),
            .init(requestID: request.id, event: .token(" body")),
            .init(requestID: request.id, event: .completed(.text("fallback")))
        ]
    }
    let adapter = MacHostedQVACDevelopmentAdapter(
        transport: transport,
        requestIDProvider: { .init("summary-request-1") }
    )
    let note = Note(
        id: .init("note-1"),
        title: "Field Notes",
        body: "Basalt cools quickly.",
        creationProvenance: .userCreated
    )

    let summary = try adapter.summary(for: [note]) { progress in
        observedProgress.append(progress)
    }

    try expect(summary == "Summary body", "QVAC development adapter should aggregate streaming tokens into the synchronous summary result")
    try expect(observedProgress == [.loadingModel, .generating], "QVAC development adapter should forward progress events")
    try expect(capturedRequests == [
        .init(
            id: .init("summary-request-1"),
            operation: .summary(.init(notes: [
                .init(noteID: "note-1", title: "Field Notes", body: "Basalt cools quickly.")
            ]))
        )
    ], "QVAC development adapter should send a narrow summary request with runtime note context only")
}

func qvacDevelopmentAdapterSmokeSkipsWhenLocalConfigIsAbsent() throws {
    let result = QVACDevelopmentAdapterSmoke.evaluate(environment: [:])

    try expect(result == .skipped("QVAC_DEV_ADAPTER_COMMAND is not configured"), "QVAC development adapter smoke should skip cleanly when local process config is absent")
}

func localProcessQVACAdapterTransportFramesRequestAndResponseLines() throws {
    let response = QVACAdapterResponse(requestID: .init("process-request-1"), event: .completed(.text("process response")))
    let script = """
    IFS= read -r request
    printf '%s\\n' \(shellSingleQuoted(try jsonLine(response)))
    """
    let transport = LocalProcessQVACAdapterTransport(commandPath: "/bin/sh", arguments: ["-c", script])

    let responses = try transport.send(.init(
        id: .init("process-request-1"),
        operation: .answer(.init(prompt: "Hello", mode: .general, context: []))
    ))

    try expect(responses == [response], "configured local process transport should exchange newline-delimited JSON over stdio")
}

func localProcessQVACAdapterTransportIgnoresOtherRequestIDsBeforeTerminalEvent() throws {
    let ignored = QVACAdapterResponse(requestID: .init("other-request"), event: .error(.init(code: "ignored", message: "wrong request")))
    let progress = QVACAdapterResponse(requestID: .init("process-request-2"), event: .progress(.generating))
    let completed = QVACAdapterResponse(requestID: .init("process-request-2"), event: .completed(.text("real response")))
    let script = """
    IFS= read -r request
    printf '%s\\n' \(shellSingleQuoted(try jsonLine(ignored)))
    printf '%s\\n' \(shellSingleQuoted(try jsonLine(progress)))
    printf '%s\\n' \(shellSingleQuoted(try jsonLine(completed)))
    """
    let transport = LocalProcessQVACAdapterTransport(commandPath: "/bin/sh", arguments: ["-c", script])

    let responses = try transport.send(.init(
        id: .init("process-request-2"),
        operation: .summary(.init(notes: []))
    ))

    try expect(responses == [progress, completed], "configured local process transport should ignore response lines for other request IDs before the real terminal event")
}

func localProcessQVACAdapterTransportReturnsAfterTerminalEventWithoutWaitingForEOF() throws {
    let response = QVACAdapterResponse(requestID: .init("process-request-3"), event: .completed(.text("done")))
    let script = """
    IFS= read -r request
    printf '%s\\n' \(shellSingleQuoted(try jsonLine(response)))
    sleep 3
    """
    let transport = LocalProcessQVACAdapterTransport(
        commandPath: "/bin/sh",
        arguments: ["-c", script],
        responseTimeout: 2
    )
    let start = Date()

    let responses = try transport.send(.init(
        id: .init("process-request-3"),
        operation: .answer(.init(prompt: "Hello", mode: .general, context: []))
    ))
    let elapsed = Date().timeIntervalSince(start)

    try expect(responses == [response], "configured local process transport should return the matching terminal response")
    try expect(elapsed < 2, "configured local process transport should not wait for process EOF after a terminal response")
}

func qvacDevelopmentAdapterPropagatesRequestScopedCancel() throws {
    let transport = CapturingLocalQVACAdapterTransport()
    let adapter = MacHostedQVACDevelopmentAdapter(
        transport: transport,
        requestIDProvider: { .init("cancel-command-1") }
    )

    try adapter.cancel(requestID: .init("running-request-1"))

    try expect(transport.sentRequests == [
        .init(id: .init("cancel-command-1"), operation: .cancel(.init("running-request-1")))
    ], "QVAC development adapter should propagate request-scoped cancellation through the local transport")
}

func qvacDevelopmentAdapterMapsCancellationEventsByRequestID() throws {
    let transport = ScriptedLocalQVACAdapterTransport { request in
        [
            .init(requestID: .init("other-request"), event: .canceled),
            .init(requestID: request.id, event: .canceled)
        ]
    }
    let adapter = MacHostedQVACDevelopmentAdapter(
        transport: transport,
        requestIDProvider: { .init("cancel-request-1") }
    )

    try expectQVACDevelopmentAdapterError(.canceled(requestID: .init("cancel-request-1"))) {
        _ = try adapter.answer(prompt: "Cancel this", mode: .general, context: [])
    }
}

func qvacDevelopmentAdapterMapsErrorEventsByRequestID() throws {
    let transport = ScriptedLocalQVACAdapterTransport { request in
        [
            .init(requestID: .init("other-request"), event: .error(.init(code: "ignored", message: "wrong request"))),
            .init(requestID: request.id, event: .error(.init(code: "model-load-failed", message: "model file missing")))
        ]
    }
    let adapter = MacHostedQVACDevelopmentAdapter(
        transport: transport,
        requestIDProvider: { .init("error-request-1") }
    )

    try expectQVACDevelopmentAdapterError(.requestFailed(
        requestID: .init("error-request-1"),
        code: "model-load-failed",
        message: "model file missing"
    )) {
        _ = try adapter.summary(for: []) { _ in }
    }
}

// MARK: - ProductionEmbeddedQVACHostAdapter behavior tests

struct ScriptedProductionEmbeddedQVACHostBridge: ProductionEmbeddedQVACHostBridge {
    let script: @Sendable (QVACAdapterRequest) -> [QVACAdapterResponse]
    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] { script(request) }
}

// Test-only: single-threaded use within one test function
final class CapturingProductionEmbeddedQVACHostBridge: @unchecked Sendable, ProductionEmbeddedQVACHostBridge {
    private(set) var capturedRequest: QVACAdapterRequest?
    private let responseFactory: @Sendable (QVACAdapterRequest) -> [QVACAdapterResponse]

    init(responseFactory: @Sendable @escaping (QVACAdapterRequest) -> [QVACAdapterResponse]) {
        self.responseFactory = responseFactory
    }

    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] {
        capturedRequest = request
        return responseFactory(request)
    }
}

func expectProductionEmbeddedQVACHostAdapterError(_ expected: ProductionEmbeddedQVACHostAdapterError, _ work: () throws -> Void) throws {
    do {
        try work()
    } catch let error as ProductionEmbeddedQVACHostAdapterError {
        try expect(error == expected, "expected \(expected), got \(error)")
        return
    }
    throw BehaviorTestFailure(description: "expected \(expected)")
}

func productionEmbeddedQVACHostAdapterAggregatesStreamedTokensIntoFinalText() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .progress(.generating)),
            .init(requestID: request.id, event: .token("Hello ")),
            .init(requestID: request.id, event: .token("world")),
            .init(requestID: request.id, event: .completed(.text("")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-1") }
    )

    let result = try adapter.answer(prompt: "hi", mode: .general, context: [])

    try expect(result == "Hello world", "production embedded QVAC host adapter should aggregate streamed tokens into the final answer")
}

func productionEmbeddedQVACHostAdapterFallsBackToCompletionTextWhenNoTokensStreamed() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .completed(.text("Full answer")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-2") }
    )

    let result = try adapter.answer(prompt: "hi", mode: .general, context: [])

    try expect(result == "Full answer", "production embedded QVAC host adapter should fall back to completion text when no tokens were streamed")
}

func productionEmbeddedQVACHostAdapterIgnoresForeignRequestIDs() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: .init("other-request"), event: .token("IGNORE ME")),
            .init(requestID: .init("other-request"), event: .completed(.text("WRONG"))),
            .init(requestID: request.id, event: .token("real ")),
            .init(requestID: request.id, event: .token("answer")),
            .init(requestID: request.id, event: .completed(.text("")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-3") }
    )

    let result = try adapter.answer(prompt: "hi", mode: .general, context: [])

    try expect(result == "real answer", "production embedded QVAC host adapter should ignore events for foreign request IDs")
}

func productionEmbeddedQVACHostAdapterMapsErrorEventToRequestFailed() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: .init("foreign-req"), event: .error(.init(code: "foreign-error", message: "should be ignored"))),
            .init(requestID: request.id, event: .error(.init(code: "model-load-failed", message: "model file missing")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-4") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .requestFailed(requestID: .init("prod-req-4"), code: "model-load-failed", message: "model file missing")
    ) {
        _ = try adapter.answer(prompt: "hi", mode: .general, context: [])
    }
}

func productionEmbeddedQVACHostAdapterMapsCanceledEventToCanceled() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: .init("other-req"), event: .canceled),
            .init(requestID: request.id, event: .canceled)
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-5") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .canceled(requestID: .init("prod-req-5"))
    ) {
        _ = try adapter.answer(prompt: "hi", mode: .general, context: [])
    }
}

func productionEmbeddedQVACHostAdapterThrowsMissingCompletionWhenNoCompletionEvent() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .progress(.generating)),
            .init(requestID: request.id, event: .token("partial"))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-6") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .missingCompletion(requestID: .init("prod-req-6"))
    ) {
        _ = try adapter.answer(prompt: "hi", mode: .general, context: [])
    }
}

func productionEmbeddedQVACHostAdapterMapsModelAvailabilityToRuntimeInventory() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .modelAvailability(.init(
                isAIReady: true,
                profiles: [
                    .init(id: "qvac-tiny", name: "QVAC Tiny", isDownloaded: true, isRemovable: false),
                    .init(id: "qvac-large", name: "QVAC Large", isDownloaded: false, isRemovable: true)
                ],
                defaultProfileID: "qvac-tiny"
            ))),
            .init(requestID: request.id, event: .completed(.text("availability-complete")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-avail-req-1") }
    )

    let availability = try adapter.modelAvailability()

    try expect(availability.isAIReady == true, "production embedded QVAC host adapter should preserve AI-ready state")
    try expect(availability.inventory == ModelInventory(
        downloadedProfiles: [
            .init(id: .init("qvac-tiny"), name: "QVAC Tiny", isDownloaded: true, isRemovable: false)
        ],
        defaultProfileID: .init("qvac-tiny")
    ), "production embedded QVAC host adapter should map only downloaded host profiles into the runtime model inventory")
}

func productionEmbeddedQVACHostAdapterModelAvailabilityErrorThrowsRequestFailed() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .error(.init(code: "unavailable", message: "no model")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-avail-req-2") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .requestFailed(requestID: .init("prod-avail-req-2"), code: "unavailable", message: "no model")
    ) {
        _ = try adapter.modelAvailability()
    }
}

func productionEmbeddedQVACHostAdapterSendsGeneralModeAndMappedContext() throws {
    let bridge = CapturingProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .token("ok")),
            .init(requestID: request.id, event: .completed(.text("")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-req-context-1") }
    )
    let note = Note(
        id: NoteID("note-abc"),
        title: "My Note",
        body: "Some body text",
        creationProvenance: .userCreated
    )

    _ = try adapter.answer(prompt: "hi", mode: .general, context: [note])

    guard let request = bridge.capturedRequest else {
        throw BehaviorTestFailure(description: "bridge should have received a request")
    }
    guard case .answer(let answerRequest) = request.operation else {
        throw BehaviorTestFailure(description: "request operation should be .answer, got \(request.operation)")
    }
    try expect(answerRequest.prompt == "hi", "answer request should carry the prompt")
    try expect(answerRequest.mode == .general, "answer request should carry .general mode")
    try expect(
        answerRequest.context == [QVACAdapterNoteContext(noteID: "note-abc", title: "My Note", body: "Some body text")],
        "answer request should map Note fields to QVACAdapterNoteContext"
    )
}

func productionEmbeddedQVACHostAdapterModelAvailabilityThrowsMissingCompletionWhenNoAvailabilityEvent() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .completed(.text("")))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-avail-missing-1") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .missingCompletion(requestID: .init("prod-avail-missing-1"))
    ) {
        _ = try adapter.modelAvailability()
    }
}

func productionEmbeddedQVACHostAdapterAnswerThrowsUnexpectedCompletionWhenPayloadIsNotText() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .completed(.relationships([])))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-unexpected-1") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .unexpectedCompletion(requestID: .init("prod-unexpected-1"))
    ) {
        _ = try adapter.answer(prompt: "hi", mode: .general, context: [])
    }
}

func productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsText() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .completed(.text("x")))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-unexpected-2") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .unexpectedCompletion(requestID: .init("prod-unexpected-2"))
    ) {
        _ = try adapter.suggestedRelationships(
            for: Note(id: .init("n1"), title: "A", body: "", creationProvenance: .userCreated),
            in: []
        )
    }
}

func productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsNoteBodies() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .completed(.noteBodies([])))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-unexpected-3") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .unexpectedCompletion(requestID: .init("prod-unexpected-3"))
    ) {
        _ = try adapter.suggestedRelationships(
            for: Note(id: .init("n1"), title: "A", body: "", creationProvenance: .userCreated),
            in: []
        )
    }
}

func productionEmbeddedQVACHostAdapterGeneratedNoteBodiesThrowsUnexpectedCompletionWhenPayloadIsText() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .completed(.text("x")))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-unexpected-4") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .unexpectedCompletion(requestID: .init("prod-unexpected-4"))
    ) {
        _ = try adapter.generatedNoteBodies(prompt: "write something", destinationCount: 1)
    }
}

func productionEmbeddedQVACHostAdapterModelAvailabilityDropsDefaultPointingAtUndownloadedProfile() throws {
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [
            .init(requestID: request.id, event: .modelAvailability(.init(
                isAIReady: true,
                profiles: [
                    .init(id: "qvac-tiny", name: "QVAC Tiny", isDownloaded: true, isRemovable: false),
                    .init(id: "qvac-large", name: "QVAC Large", isDownloaded: false, isRemovable: true)
                ],
                defaultProfileID: "qvac-large"
            )))
        ]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("prod-avail-drop-default-1") }
    )

    let availability = try adapter.modelAvailability()

    try expect(
        availability.inventory.defaultProfileID == nil,
        "model availability should drop defaultProfileID when the named profile is not downloaded"
    )
    try expect(
        availability.inventory.downloadedProfiles == [
            LocalModelProfile(id: .init("qvac-tiny"), name: "QVAC Tiny", isDownloaded: true, isRemovable: false)
        ],
        "model availability should still include downloaded profiles even when defaultProfileID is dropped"
    )
}

func qvacDevelopmentAdapterMapsModelAvailabilityToRuntimeInventory() throws {
    let transport = ScriptedLocalQVACAdapterTransport { request in
        [
            .init(requestID: request.id, event: .modelAvailability(.init(
                isAIReady: true,
                profiles: [
                    .init(id: "qvac-tiny", name: "QVAC Tiny", isDownloaded: true, isRemovable: false),
                    .init(id: "qvac-large", name: "QVAC Large", isDownloaded: false, isRemovable: true)
                ],
                defaultProfileID: "qvac-tiny"
            ))),
            .init(requestID: request.id, event: .completed(.text("availability-complete")))
        ]
    }
    let adapter = MacHostedQVACDevelopmentAdapter(
        transport: transport,
        requestIDProvider: { .init("availability-request-1") }
    )

    let availability = try adapter.modelAvailability()

    try expect(availability.isAIReady == true, "QVAC model availability should preserve AI-ready state")
    try expect(availability.inventory == ModelInventory(
        downloadedProfiles: [
            .init(id: .init("qvac-tiny"), name: "QVAC Tiny", isDownloaded: true, isRemovable: false)
        ],
        defaultProfileID: .init("qvac-tiny")
    ), "QVAC model availability should map downloaded host profiles into runtime Model Inventory")
}

// MARK: - Task 16b: Embedded host answer wire-protocol tests

// These tests verify that the public QVACAdapterProtocol types used by the
// answer bridge round-trip through JSON with the exact field names the JS
// answer-responder expects, and that the adapter events map correctly.

func embeddedHostAnswerWireRequestEncodesProtocolTypeAndFieldsForJSResponder() throws {
    // The answer bridge adapter JSON-encodes a QVACAdapterAnswerRequest into its wire payload.
    // We verify the public Codable types round-trip with full fidelity across prompt, mode,
    // and context fields — the same fields the JS answer-responder parses.
    let answerRequest = QVACAdapterAnswerRequest(
        prompt: "Summarise my notes",
        mode: .noteGrounded,
        context: [.init(noteID: "note-42", title: "Fieldwork", body: "Basalt.")]
    )

    let encoded = try JSONEncoder().encode(answerRequest)
    let decoded = try JSONDecoder().decode(QVACAdapterAnswerRequest.self, from: encoded)

    try expect(decoded.prompt == "Summarise my notes", "answer request prompt should survive Codable round-trip")
    try expect(decoded.mode == .noteGrounded, "answer request mode .noteGrounded should survive Codable round-trip")
    try expect(decoded.context.count == 1, "answer request context count should survive Codable round-trip")
    try expect(decoded.context[0].noteID == "note-42", "answer request context noteID should survive Codable round-trip")
    try expect(decoded.context[0].title == "Fieldwork", "answer request context title should survive Codable round-trip")
    try expect(decoded.context[0].body == "Basalt.", "answer request context body should survive Codable round-trip")

    // Also verify .general mode round-trips (it uses a different raw value)
    let generalRequest = QVACAdapterAnswerRequest(prompt: "hi", mode: .general, context: [])
    let generalEncoded = try JSONEncoder().encode(generalRequest)
    let generalDecoded = try JSONDecoder().decode(QVACAdapterAnswerRequest.self, from: generalEncoded)
    try expect(generalDecoded.mode == .general, "answer request mode .general should survive Codable round-trip")
}

func embeddedHostAnswerWireCompletedTextResponseRoundTripsAsQVACAdapterEvent() throws {
    // The bridge adapter maps a completed-text response to a .completed(.text) event.
    // Verify this mapping using the ProductionEmbeddedQVACHostAdapter (public runtime type).
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .completed(.text("The answer is 42.")))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("answer-wire-completed-1") }
    )

    let result = try adapter.answer(prompt: "What is the answer?", mode: .general, context: [])

    try expect(result == "The answer is 42.", "completed-text response should be returned as the answer string")
}

func embeddedHostAnswerWireErrorResponseMapsToQVACAdapterErrorEvent() throws {
    // The bridge adapter maps an error response to a .error event, which the adapter
    // converts to a thrown requestFailed error.
    let bridge = ScriptedProductionEmbeddedQVACHostBridge { request in
        [.init(requestID: request.id, event: .error(.init(code: "model-unavailable", message: "Model not loaded.")))]
    }
    let adapter = ProductionEmbeddedQVACHostAdapter(
        bridge: bridge,
        requestIDProvider: { .init("answer-wire-error-1") }
    )

    try expectProductionEmbeddedQVACHostAdapterError(
        .requestFailed(requestID: .init("answer-wire-error-1"), code: "model-unavailable", message: "Model not loaded.")
    ) {
        _ = try adapter.answer(prompt: "What is the answer?", mode: .general, context: [])
    }
}

let tests: [(String, () async throws -> Void)] = [
    ("diagnosticsExportIsUserInitiatedAndContentFree", diagnosticsExportIsUserInitiatedAndContentFree),
    ("contentFreeLogEntryAcceptsAllowedOperationalMetadata", contentFreeLogEntryAcceptsAllowedOperationalMetadata),
    ("contentFreeLogEntryRejectsForbiddenContentFields", contentFreeLogEntryRejectsForbiddenContentFields),
    ("crashReportPayloadIsOptionalAndContentFree", crashReportPayloadIsOptionalAndContentFree),
    ("creatingANoteThroughRuntimeCommandCanBeReadThroughRuntimeQuery", creatingANoteThroughRuntimeCommandCanBeReadThroughRuntimeQuery),
    ("creatingANoteCanPreserveAHostSuppliedNoteID", creatingANoteCanPreserveAHostSuppliedNoteID),
    ("sqliteBackedRuntimePersistsCreatedNoteAcrossRuntimeInstances", sqliteBackedRuntimePersistsCreatedNoteAcrossRuntimeInstances),
    ("sqliteBackedRuntimePreservesNoteFieldsAcrossRuntimeInstances", sqliteBackedRuntimePreservesNoteFieldsAcrossRuntimeInstances),
    ("sqliteBackedRuntimeSupportsNoteLifecycleAndSearchAcrossRuntimeInstances", sqliteBackedRuntimeSupportsNoteLifecycleAndSearchAcrossRuntimeInstances),
    ("sqliteBackedRuntimeDisambiguatesTitlesAgainstPersistedNotes", sqliteBackedRuntimeDisambiguatesTitlesAgainstPersistedNotes),
    ("sqliteBackedRuntimeListsTrashedNotesAcrossRuntimeInstances", sqliteBackedRuntimeListsTrashedNotesAcrossRuntimeInstances),
    ("pinnedNotesPersistAndAppearAboveRegularHomeGroupsAcrossRuntimeInstances", pinnedNotesPersistAndAppearAboveRegularHomeGroupsAcrossRuntimeInstances),
    ("regularHomeGroupsUseRuntimeLastEditedTimeOrdering", regularHomeGroupsUseRuntimeLastEditedTimeOrdering),
    ("emptyUserCreatedNotesAreDiscardedWhilePlaceholderNotesRemainSupported", emptyUserCreatedNotesAreDiscardedWhilePlaceholderNotesRemainSupported),
    ("userCreatedNoteDraftDiscardPolicyRequiresEmptyTitleAndBody", userCreatedNoteDraftDiscardPolicyRequiresEmptyTitleAndBody),
    ("textFirstV1PolicyDisablesAttachmentAndMultimodalEntryPoints", textFirstV1PolicyDisablesAttachmentAndMultimodalEntryPoints),
    ("textFirstV1PolicyRejectsArchivedTablePresentationState", textFirstV1PolicyRejectsArchivedTablePresentationState),
    ("textFirstV1PolicyRejectsArchivedObjectReplacementPresentationState", textFirstV1PolicyRejectsArchivedObjectReplacementPresentationState),
    ("textFirstV1PolicyCoversAppEntryPointMappings", textFirstV1PolicyCoversAppEntryPointMappings),
    ("textFirstV1AppGuardMakesExactNoteAndChatDecisions", textFirstV1AppGuardMakesExactNoteAndChatDecisions),
    ("supportedMarkdownRoundTripsHeadings", supportedMarkdownRoundTripsHeadings),
    ("supportedMarkdownRoundTripsInlineFormattingAndHtmlAllowlist", supportedMarkdownRoundTripsInlineFormattingAndHtmlAllowlist),
    ("supportedMarkdownEditorBridgeKeepsLiteralBoldMarkersPlain", supportedMarkdownEditorBridgeKeepsLiteralBoldMarkersPlain),
    ("supportedMarkdownEditorBridgeKeepsLiteralInlineMarkersPlain", supportedMarkdownEditorBridgeKeepsLiteralInlineMarkersPlain),
    ("supportedMarkdownEditorBridgeKeepsLiteralHeadingMarkerParagraphPlain", supportedMarkdownEditorBridgeKeepsLiteralHeadingMarkerParagraphPlain),
    ("supportedMarkdownEditorBridgeKeepsLiteralBlockMarkersParagraphPlain", supportedMarkdownEditorBridgeKeepsLiteralBlockMarkersParagraphPlain),
    ("supportedMarkdownEditorBridgeCreatesTitleBasedWikilinkInsertionText", supportedMarkdownEditorBridgeCreatesTitleBasedWikilinkInsertionText),
    ("supportedMarkdownRoundTripsBoldItalicInlineCombination", supportedMarkdownRoundTripsBoldItalicInlineCombination),
    ("supportedMarkdownRoundTripsBoldUnderlineInlineCombination", supportedMarkdownRoundTripsBoldUnderlineInlineCombination),
    ("supportedMarkdownRoundTripsUnderlineStrikethroughInlineCombination", supportedMarkdownRoundTripsUnderlineStrikethroughInlineCombination),
    ("supportedMarkdownRoundTripsBlockFormatting", supportedMarkdownRoundTripsBlockFormatting),
    ("supportedMarkdownRoundTripsFencedCodeLanguageAndBlankLines", supportedMarkdownRoundTripsFencedCodeLanguageAndBlankLines),
    ("supportedMarkdownRoundTripsListsAndTables", supportedMarkdownRoundTripsListsAndTables),
    ("supportedMarkdownEditorPresentationReloadsFormattingFamilies", supportedMarkdownEditorPresentationReloadsFormattingFamilies),
    ("supportedMarkdownEditorBridgePreservesFencedCodeLanguageAcrossReloadAndSave", supportedMarkdownEditorBridgePreservesFencedCodeLanguageAcrossReloadAndSave),
    ("supportedMarkdownEditorBridgePreservesReloadedFencedCodeBlankLinesAcrossEditorBufferSave", supportedMarkdownEditorBridgePreservesReloadedFencedCodeBlankLinesAcrossEditorBufferSave),
    ("supportedMarkdownEditorBridgeKeepsTypedFencedCodeBlankLinesInOneBlockRange", supportedMarkdownEditorBridgeKeepsTypedFencedCodeBlankLinesInOneBlockRange),
    ("supportedMarkdownEditorBridgeSavesPlainEditorParagraphBlockMarkersWithoutShapePromotion", supportedMarkdownEditorBridgeSavesPlainEditorParagraphBlockMarkersWithoutShapePromotion),
    ("supportedMarkdownEditorBridgeSavesExplicitEditorBlockIntentAsFormatting", supportedMarkdownEditorBridgeSavesExplicitEditorBlockIntentAsFormatting),
    ("richTextEditorUsesRuntimeMarkdownBridgeForReloadAndCodeLanguagePersistence", richTextEditorUsesRuntimeMarkdownBridgeForReloadAndCodeLanguagePersistence),
    ("richTextEditorSavePathUsesExplicitRuntimeBlockIntentWithoutRawShapePromotion", richTextEditorSavePathUsesExplicitRuntimeBlockIntentWithoutRawShapePromotion),
    ("noteEditorWiresTitleBasedWikilinkInsertionThroughRuntimeSavePath", noteEditorWiresTitleBasedWikilinkInsertionThroughRuntimeSavePath),
    ("productionNoteSaveUsesRuntimeEditorSaveWorkflow", productionNoteSaveUsesRuntimeEditorSaveWorkflow),
    ("noteEditorWorkflowInsertsExistingNoteWikilinkAndPersistsExplicitLink", noteEditorWorkflowInsertsExistingNoteWikilinkAndPersistsExplicitLink),
    ("noteEditorWorkflowSaveCreatesPlaceholderForManualUnresolvedWikilink", noteEditorWorkflowSaveCreatesPlaceholderForManualUnresolvedWikilink),
    ("noteEditorWorkflowSavePromotesPlaceholderWhenBodyIsAuthored", noteEditorWorkflowSavePromotesPlaceholderWhenBodyIsAuthored),
    ("defaultUserSearchSearchesActiveNotesOnlyAndExcludesTrash", defaultUserSearchSearchesActiveNotesOnlyAndExcludesTrash),
    ("sqliteBackedRuntimeDoesNotReuseGeneratedNoteIDsAfterPermanentDeletion", sqliteBackedRuntimeDoesNotReuseGeneratedNoteIDsAfterPermanentDeletion),
    ("sqliteBackedRuntimeSurfacesPersistenceReadErrorsAsThrownRuntimeErrors", sqliteBackedRuntimeSurfacesPersistenceReadErrorsAsThrownRuntimeErrors),
    ("runtimeNoteIDMappingStorePreservesNonUUIDRuntimeIDsForHostPresentation", runtimeNoteIDMappingStorePreservesNonUUIDRuntimeIDsForHostPresentation),
    ("runtimeNoteIDMappingStoreSharesRuntimeSQLiteFileWithPersistedNotes", runtimeNoteIDMappingStoreSharesRuntimeSQLiteFileWithPersistedNotes),
    ("runtimeNoteIDMappingStoreSurfacesReverseLookupReadErrors", runtimeNoteIDMappingStoreSurfacesReverseLookupReadErrors),
    ("importingIndividualMarkdownFileCreatesNoteWithRawBodyAndProvenance", importingIndividualMarkdownFileCreatesNoteWithRawBodyAndProvenance),
    ("importingMarkdownFolderCreatesFlatDisambiguatedNotesWithoutReplacingExistingNotes", importingMarkdownFolderCreatesFlatDisambiguatedNotesWithoutReplacingExistingNotes),
    ("importingMarkdownResolvesWikilinksMarkdownLinksAndUnresolvedWikilinkPlaceholders", importingMarkdownResolvesWikilinksMarkdownLinksAndUnresolvedWikilinkPlaceholders),
    ("importingUnresolvedMarkdownLinkCreatesPlaceholderNoteAndExplicitLink", importingUnresolvedMarkdownLinkCreatesPlaceholderNoteAndExplicitLink),
    ("importingFolderResolvesLinksToImportedNotesBeforeExistingLocalTitles", importingFolderResolvesLinksToImportedNotesBeforeExistingLocalTitles),
    ("importingFolderResolvesRelativeMarkdownLinksByPathBeforeDuplicateBasenameTitles", importingFolderResolvesRelativeMarkdownLinksByPathBeforeDuplicateBasenameTitles),
    ("renamingImportedMarkdownLinkTargetDoesNotRewriteUnrelatedWikilink", renamingImportedMarkdownLinkTargetDoesNotRewriteUnrelatedWikilink),
    ("renamingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRewriteUnrelatedWikilink", renamingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRewriteUnrelatedWikilink),
    ("renamingAndDeletingImportedManifestOnlyTargetDoesNotRewriteOrRemoveBodyWikilink", renamingAndDeletingImportedManifestOnlyTargetDoesNotRewriteOrRemoveBodyWikilink),
    ("permanentlyDeletingImportedMarkdownLinkTargetDoesNotRemoveUnrelatedWikilink", permanentlyDeletingImportedMarkdownLinkTargetDoesNotRemoveUnrelatedWikilink),
    ("permanentlyDeletingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRemoveUnrelatedWikilink", permanentlyDeletingImportedMarkdownLinkTargetWithManifestExtraEdgeDoesNotRemoveUnrelatedWikilink),
    ("renamingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge", renamingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge),
    ("renamingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges", renamingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges),
    ("permanentlyDeletingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge", permanentlyDeletingImportedWikilinkTargetPreservesUnrelatedMarkdownLinkExplicitEdge),
    ("permanentlyDeletingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges", permanentlyDeletingImportedWikilinkTargetWithManifestExtraEdgePreservesMarkdownAndManifestEdges),
    ("importingExportBundlePreservesUnsupportedSyntaxAndAttachmentReferencesWithoutAttachmentSideEffects", importingExportBundlePreservesUnsupportedSyntaxAndAttachmentReferencesWithoutAttachmentSideEffects),
    ("importingExportBundleUsesManifestToPreserveNoteIDsRelationshipsAndProvenance", importingExportBundleUsesManifestToPreserveNoteIDsRelationshipsAndProvenance),
    ("importingExportBundleDeduplicatesManifestExplicitLinksAlreadyPresentInBody", importingExportBundleDeduplicatesManifestExplicitLinksAlreadyPresentInBody),
    ("markdownExportUsesFilesystemSafeFilenamesAndMapsThemToNoteIDs", markdownExportUsesFilesystemSafeFilenamesAndMapsThemToNoteIDs),
    ("markdownExportDisambiguatesCaseInsensitiveFilenameCollisions", markdownExportDisambiguatesCaseInsensitiveFilenameCollisions),
    ("markdownExportStoresAcceptedRelationshipsInManifestOnly", markdownExportStoresAcceptedRelationshipsInManifestOnly),
    ("exportBundleExcludesTrashByDefaultAndIncludesTrashWhenRequested", exportBundleExcludesTrashByDefaultAndIncludesTrashWhenRequested),
    ("exportBundleIncludesAISessionHistoryOnlyWhenRequested", exportBundleIncludesAISessionHistoryOnlyWhenRequested),
    ("exportBundleIncludesEditProvenanceOnlyWhenRequested", exportBundleIncludesEditProvenanceOnlyWhenRequested),
    ("exportBundlePreservesImportProvenanceInManifest", exportBundlePreservesImportProvenanceInManifest),
    ("exportBundlePreservesExplicitLinksInManifest", exportBundlePreservesExplicitLinksInManifest),
    ("markdownExportRendersExplicitLinksWithCurrentTargetTitles", markdownExportRendersExplicitLinksWithCurrentTargetTitles),
    ("singleNoteShareReturnsCleanContentOnly", singleNoteShareReturnsCleanContentOnly),
    ("renamingANoteThroughRuntimeCommandPreservesStableNoteID", renamingANoteThroughRuntimeCommandPreservesStableNoteID),
    ("renamingANoteRewritesSelfLinkingWikilinksByStableNoteID", renamingANoteRewritesSelfLinkingWikilinksByStableNoteID),
    ("updatingANoteBodyThroughRuntimeCommandPreservesRawMarkdownAuthority", updatingANoteBodyThroughRuntimeCommandPreservesRawMarkdownAuthority),
    ("listingNotesThroughRuntimeQueryReturnsCreatedNotes", listingNotesThroughRuntimeQueryReturnsCreatedNotes),
    ("creatingDuplicateNoteTitlesAppliesTitleDisambiguation", creatingDuplicateNoteTitlesAppliesTitleDisambiguation),
    ("renamingToDuplicateNoteTitleAppliesTitleDisambiguationWithoutChangingNoteID", renamingToDuplicateNoteTitleAppliesTitleDisambiguationWithoutChangingNoteID),
    ("wikilinksInNoteBodyCreateExplicitLinksToExistingNoteIDs", wikilinksInNoteBodyCreateExplicitLinksToExistingNoteIDs),
    ("renamingANoteRewritesIncomingWikilinksByStableNoteID", renamingANoteRewritesIncomingWikilinksByStableNoteID),
    ("renamingANoteRewritesIncomingWikilinksInTrashedSourcesWithoutUserEditTimestamps", renamingANoteRewritesIncomingWikilinksInTrashedSourcesWithoutUserEditTimestamps),
    ("unresolvedWikilinksCreateVisiblePlaceholderNotesAndExplicitLinks", unresolvedWikilinksCreateVisiblePlaceholderNotesAndExplicitLinks),
    ("addingBodyContentToPlaceholderNotePromotesItToNormalNote", addingBodyContentToPlaceholderNotePromotesItToNormalNote),
    ("backlinksAreDerivedFromExplicitLinksWithSourceTitleAndSnippet", backlinksAreDerivedFromExplicitLinksWithSourceTitleAndSnippet),
    ("repeatedWikilinksRemainMultipleExplicitLinkOccurrences", repeatedWikilinksRemainMultipleExplicitLinkOccurrences),
    ("trustedGraphIncludesExplicitLinksWithProvenance", trustedGraphIncludesExplicitLinksWithProvenance),
    ("sqliteBackedRuntimePersistsTrustedGraphEdgesAcrossRuntimeInstances", sqliteBackedRuntimePersistsTrustedGraphEdgesAcrossRuntimeInstances),
    ("sqliteBackedRuntimeBackfillsTrustedGraphEdgesFromStoredNoteBodies", sqliteBackedRuntimeBackfillsTrustedGraphEdgesFromStoredNoteBodies),
    ("trustedGraphMarksPlaceholderNodesFromUnresolvedWikilinks", trustedGraphMarksPlaceholderNodesFromUnresolvedWikilinks),
    ("presentationTrustedGraphMapsRuntimeMembershipAndPlaceholderKind", presentationTrustedGraphMapsRuntimeMembershipAndPlaceholderKind),
    ("presentationTrustedGraphOpenIntentDistinguishesPlaceholderPromotion", presentationTrustedGraphOpenIntentDistinguishesPlaceholderPromotion),
    ("trustedGraphDeduplicatesRepeatedExplicitLinkEdges", trustedGraphDeduplicatesRepeatedExplicitLinkEdges),
    ("trustedGraphExcludesTrashedNotesAndEdgesInvolvingThem", trustedGraphExcludesTrashedNotesAndEdgesInvolvingThem),
    ("trustedGraphIncludesUserCreatedAcceptedRelationshipsWithoutChangingNoteBodies", trustedGraphIncludesUserCreatedAcceptedRelationshipsWithoutChangingNoteBodies),
    ("aiCannotCreateAcceptedRelationships", aiCannotCreateAcceptedRelationships),
    ("trustedGraphExcludesAcceptedRelationshipEdgesInvolvingTrash", trustedGraphExcludesAcceptedRelationshipEdgesInvolvingTrash),
    ("relationshipScanReturnsSuggestedRelationshipsWithoutChangingTrustedGraph", relationshipScanReturnsSuggestedRelationshipsWithoutChangingTrustedGraph),
    ("relationshipScanFailsFastWithoutUsableLocalModelProfile", relationshipScanFailsFastWithoutUsableLocalModelProfile),
    ("frontendRelationshipScanPolicyKeepsSuggestionsOutOfTrustedGraphPresentationUntilPromotion", frontendRelationshipScanPolicyKeepsSuggestionsOutOfTrustedGraphPresentationUntilPromotion),
    ("relationshipScanRejectsPlaceholderNotesWithoutChangingGraph", relationshipScanRejectsPlaceholderNotesWithoutChangingGraph),
    ("relationshipScanRejectsNotesInTrashWithoutChangingGraph", relationshipScanRejectsNotesInTrashWithoutChangingGraph),
    ("userPromotionConvertsSuggestionIntoAcceptedRelationshipWithoutExplicitLink", userPromotionConvertsSuggestionIntoAcceptedRelationshipWithoutExplicitLink),
    ("aiCannotPromoteSuggestedRelationships", aiCannotPromoteSuggestedRelationships),
    ("embedReferencesRemainRawContentWithoutExplicitLinks", embedReferencesRemainRawContentWithoutExplicitLinks),
    ("movingANoteToTrashPreservesContentExplicitLinksAndProvenance", movingANoteToTrashPreservesContentExplicitLinksAndProvenance),
    ("movingWikilinkTargetToTrashPreservesIncomingSourceWikilinks", movingWikilinkTargetToTrashPreservesIncomingSourceWikilinks),
    ("trashUndoRestoresTheNoteToActiveState", trashUndoRestoresTheNoteToActiveState),
    ("explicitRestoreFromTrashPreservesContentExplicitLinksBacklinksAndProvenance", explicitRestoreFromTrashPreservesContentExplicitLinksBacklinksAndProvenance),
    ("permanentDeleteRequiresTrashedNoteAndDeletionConfirmation", permanentDeleteRequiresTrashedNoteAndDeletionConfirmation),
    ("permanentlyDeletingANoteRemovesIncomingWikilinksWithoutUserEditTimestamps", permanentlyDeletingANoteRemovesIncomingWikilinksWithoutUserEditTimestamps),
    ("aiFacingRuntimeCommandsCannotMoveNotesToTrashOrPermanentlyDeleteNotes", aiFacingRuntimeCommandsCannotMoveNotesToTrashOrPermanentlyDeleteNotes),
    ("aiCannotUndoTrash", aiCannotUndoTrash),
    ("aiCannotRestoreNoteFromTrash", aiCannotRestoreNoteFromTrash),
    ("userSearchWorksWithoutLocalModelProfileOverNoteTitles", userSearchWorksWithoutLocalModelProfileOverNoteTitles),
    ("userSearchReturnsActiveNotesByKeywordMatchOverRawMarkdownNoteBodies", userSearchReturnsActiveNotesByKeywordMatchOverRawMarkdownNoteBodies),
    ("creatingANoteMarksUserSearchDerivedIndexDirty", creatingANoteMarksUserSearchDerivedIndexDirty),
    ("updatingANoteBodyMarksUserSearchDerivedIndexDirty", updatingANoteBodyMarksUserSearchDerivedIndexDirty),
    ("renamingANoteMarksUserSearchDerivedIndexDirty", renamingANoteMarksUserSearchDerivedIndexDirty),
    ("movingANoteToTrashRemovesItFromRefreshedUserSearchResults", movingANoteToTrashRemovesItFromRefreshedUserSearchResults),
    ("restoringANoteFromTrashMarksUserSearchDerivedIndexDirty", restoringANoteFromTrashMarksUserSearchDerivedIndexDirty),
    ("undoingTrashMarksUserSearchDerivedIndexDirty", undoingTrashMarksUserSearchDerivedIndexDirty),
    ("aiAvailabilityReportsUnavailableWithoutLocalModelProfileWhileNotesAndUserSearchWork", aiAvailabilityReportsUnavailableWithoutLocalModelProfileWhileNotesAndUserSearchWork),
    ("recordingLocalModelProfileMakesDeviceAIReadyAndChoosesIt", recordingLocalModelProfileMakesDeviceAIReadyAndChoosesIt),
    ("refreshingModelAvailabilityFromAdapterRecordsDownloadedDefaultProfile", refreshingModelAvailabilityFromAdapterRecordsDownloadedDefaultProfile),
    ("refreshingUnavailableAdapterModelAvailabilityClearsStaleHostProfile", refreshingUnavailableAdapterModelAvailabilityClearsStaleHostProfile),
    ("refreshingAdapterModelAvailabilityPreservesUsableManualDefaultProfile", refreshingAdapterModelAvailabilityPreservesUsableManualDefaultProfile),
    ("refreshingUnavailableAdapterModelAvailabilityPreservesManualProfileWithSameID", refreshingUnavailableAdapterModelAvailabilityPreservesManualProfileWithSameID),
    ("settingDefaultLocalModelProfileChoosesItFromMultipleProfiles", settingDefaultLocalModelProfileChoosesItFromMultipleProfiles),
    ("clearingDefaultLocalModelProfileReturnsChoiceToFirstAvailableProfile", clearingDefaultLocalModelProfileReturnsChoiceToFirstAvailableProfile),
    ("removingDefaultLocalModelProfileClearsDefaultAndChoosesRemainingProfile", removingDefaultLocalModelProfileClearsDefaultAndChoosesRemainingProfile),
    ("removingNonRemovableLocalModelProfileFailsAndLeavesInventoryUnchanged", removingNonRemovableLocalModelProfileFailsAndLeavesInventoryUnchanged),
    ("nonDownloadedLocalModelProfileDoesNotMakeDeviceAIReadyOrWorkflowSelectable", nonDownloadedLocalModelProfileDoesNotMakeDeviceAIReadyOrWorkflowSelectable),
    ("settingDefaultToNonDownloadedLocalModelProfileFailsAndLeavesDefaultOmitted", settingDefaultToNonDownloadedLocalModelProfileFailsAndLeavesDefaultOmitted),
    ("aiAvailabilityCheckFailsFastUntilUsableLocalModelProfileExists", aiAvailabilityCheckFailsFastUntilUsableLocalModelProfileExists),
    ("answerRequestDefaultsToNoteGroundedAndReturnsSourceCitations", answerRequestDefaultsToNoteGroundedAndReturnsSourceCitations),
    ("noteGroundedAnswerFailsFastWithoutAIReadyDevice", noteGroundedAnswerFailsFastWithoutAIReadyDevice),
    ("noteGroundedAnswerRequiresFreshUserSearchIndex", noteGroundedAnswerRequiresFreshUserSearchIndex),
    ("noteGroundedRetrievalExpandsThroughExplicitLinks", noteGroundedRetrievalExpandsThroughExplicitLinks),
    ("noteGroundedRetrievalExpandsThroughAcceptedRelationships", noteGroundedRetrievalExpandsThroughAcceptedRelationships),
    ("noteGroundedRetrievalWeightsExplicitLinksBeforeAcceptedRelationships", noteGroundedRetrievalWeightsExplicitLinksBeforeAcceptedRelationships),
    ("noteGroundedAnswerDoesNotUsePlaceholderOrTrashAsFallbackContext", noteGroundedAnswerDoesNotUsePlaceholderOrTrashAsFallbackContext),
    ("noContextNoteGroundedAnswerRequiresGeneralFallbackConfirmation", noContextNoteGroundedAnswerRequiresGeneralFallbackConfirmation),
    ("sourceCitationPresentationKeepsNoteTitleStableIDAndFragmentSeparate", sourceCitationPresentationKeepsNoteTitleStableIDAndFragmentSeparate),
    ("chatAnswerRequestGuardPreventsCanceledAndStaleResultsFromApplying", chatAnswerRequestGuardPreventsCanceledAndStaleResultsFromApplying),
    ("chatAnswerPresentationStateClearsStaleCitationsAndErrorsForNewAndCanceledRequests", chatAnswerPresentationStateClearsStaleCitationsAndErrorsForNewAndCanceledRequests),
    ("aiSessionHistoryPresentationMapsRuntimeMetadata", aiSessionHistoryPresentationMapsRuntimeMetadata),
    ("chatHistoryDeletionPresentationStateSurfacesAndClearsDeleteFailures", chatHistoryDeletionPresentationStateSurfacesAndClearsDeleteFailures),
    ("developmentModelProfilePolicyRequiresExplicitOptIn", developmentModelProfilePolicyRequiresExplicitOptIn),
    ("placeholderSeedCannotExpandContextRetrievalThroughGraph", placeholderSeedCannotExpandContextRetrievalThroughGraph),
    ("generalAnswerIsExplicitlyUnconstrainedAndDoesNotRequireFreshIndex", generalAnswerIsExplicitlyUnconstrainedAndDoesNotRequireFreshIndex),
    ("aiAnswersAreRecordedInLocalAISessionHistoryByDefault", aiAnswersAreRecordedInLocalAISessionHistoryByDefault),
    ("aiSessionHistoryRecordsAnswerMetadata", aiSessionHistoryRecordsAnswerMetadata),
    ("aiSessionHistoryCanBeDeletedThroughRuntimeCommand", aiSessionHistoryCanBeDeletedThroughRuntimeCommand),
    ("aiCannotDeleteAISessionHistory", aiCannotDeleteAISessionHistory),
    ("aiSessionHistoryIsExcludedFromContextRetrieval", aiSessionHistoryIsExcludedFromContextRetrieval),
    ("aiGeneratedWriteRequiresExplicitDestinationBeforeDurableResult", aiGeneratedWriteRequiresExplicitDestinationBeforeDurableResult),
    ("aiSourceCannotBypassAIWriteModelWithDirectNoteMutations", aiSourceCannotBypassAIWriteModelWithDirectNoteMutations),
    ("aiSourceCannotBypassAIWriteModelWithRenameOrSavedResponse", aiSourceCannotBypassAIWriteModelWithRenameOrSavedResponse),
    ("aiSourceCannotSetEditingPermissionOrAcceptDraftChange", aiSourceCannotSetEditingPermissionOrAcceptDraftChange),
    ("aiCannotCancelDraftChange", aiCannotCancelDraftChange),
    ("acceptingDraftChangeAppliesGeneratedContentLinksAndRecordsAIOperation", acceptingDraftChangeAppliesGeneratedContentLinksAndRecordsAIOperation),
    ("cancelingDraftChangeCreatesNoDurableNoteGraphOrOperationResult", cancelingDraftChangeCreatesNoDurableNoteGraphOrOperationResult),
    ("draftAcceptanceDoesNotMutateNoteOrGraphWhenAIOperationCommitFails", draftAcceptanceDoesNotMutateNoteOrGraphWhenAIOperationCommitFails),
    ("directEditAppliesGeneratedContentImmediatelyAndRecordsAIOperation", directEditAppliesGeneratedContentImmediatelyAndRecordsAIOperation),
    ("directEditCommitsAtomicallyWhenOneOfMultipleChangesIsInvalid", directEditCommitsAtomicallyWhenOneOfMultipleChangesIsInvalid),
    ("directEditDoesNotMutateNoteOrGraphWhenAIOperationCommitFails", directEditDoesNotMutateNoteOrGraphWhenAIOperationCommitFails),
    ("reversingDirectEditRestoresPreviousNoteContentAndGraphSideEffects", reversingDirectEditRestoresPreviousNoteContentAndGraphSideEffects),
    ("generatedUnresolvedWikilinksCreateDisambiguatedPlaceholderNotesWhenContentBecomesDurable", generatedUnresolvedWikilinksCreateDisambiguatedPlaceholderNotesWhenContentBecomesDurable),
    ("reversingDirectEditRemovesPlaceholderNoteCreatedByGeneratedWikilink", reversingDirectEditRemovesPlaceholderNoteCreatedByGeneratedWikilink),
    ("simulatedCrashDiscardsIncompleteAIOperationWithoutPartialNoteChange", simulatedCrashDiscardsIncompleteAIOperationWithoutPartialNoteChange),
    ("simulatedIncompleteDirectAIWriteLeavesNoPartialNoteGraphOrOperationChange", simulatedIncompleteDirectAIWriteLeavesNoPartialNoteGraphOrOperationChange),
    ("simulatedIncompleteDraftAcceptanceLeavesNoPartialNoteGraphOrOperationChange", simulatedIncompleteDraftAcceptanceLeavesNoPartialNoteGraphOrOperationChange),
    ("savingAIResponseToNewNoteCreatesNoteContentLinksIndexAndOperationMarker", savingAIResponseToNewNoteCreatesNoteContentLinksIndexAndOperationMarker),
    ("savingAIResponseToNewNoteRecordsChosenLocalModelProfileInAIOperation", savingAIResponseToNewNoteRecordsChosenLocalModelProfileInAIOperation),
    ("reversingSavedAIResponseOperationRemovesCreatedNoteFromActiveNotes", reversingSavedAIResponseOperationRemovesCreatedNoteFromActiveNotes),
    ("aiCannotReverseSavedAIResponseOperation", aiCannotReverseSavedAIResponseOperation),
    ("savingAIResponseToDraftChangeCreatesDraftWithoutMutatingNoteBody", savingAIResponseToDraftChangeCreatesDraftWithoutMutatingNoteBody),
    ("responseOnlySummaryReturnsTextWithoutDurableState", responseOnlySummaryReturnsTextWithoutDurableState),
    ("summaryRoutedToDraftChangeCreatesDraftWithoutMutatingTargetNote", summaryRoutedToDraftChangeCreatesDraftWithoutMutatingTargetNote),
    ("acceptingSummaryDraftChangeAppliesContentWithReversibleAIOperation", acceptingSummaryDraftChangeAppliesContentWithReversibleAIOperation),
    ("summaryRoutedToNewNoteWithDirectPermissionCreatesReversibleAIOperation", summaryRoutedToNewNoteWithDirectPermissionCreatesReversibleAIOperation),
    ("reversingNewNoteSummaryRemovesGeneratedWikilinkPlaceholderAndGraphSideEffects", reversingNewNoteSummaryRemovesGeneratedWikilinkPlaceholderAndGraphSideEffects),
    ("newNoteSummaryRequiresDirectEditingPermission", newNoteSummaryRequiresDirectEditingPermission),
    ("blockedNewNoteSummaryDoesNotInvokeAIAdapter", blockedNewNoteSummaryDoesNotInvokeAIAdapter),
    ("summaryFailsFastWhenAIIsUnavailableWithoutDurableState", summaryFailsFastWhenAIIsUnavailableWithoutDurableState),
    ("summaryOverSelectedNoteSetIncludesEachSourceDeterministically", summaryOverSelectedNoteSetIncludesEachSourceDeterministically),
    ("summaryCanUseRetrievedNotesFromPrompt", summaryCanUseRetrievedNotesFromPrompt),
    ("summaryExposesProgressStateTransitionsDuringWorkflow", summaryExposesProgressStateTransitionsDuringWorkflow),
    ("aiProgressStateRepresentsIdleLoadingAndGeneratingPhases", aiProgressStateRepresentsIdleLoadingAndGeneratingPhases),
    ("qvacAdapterProtocolRoundTripsRequestIDsAndOperations", qvacAdapterProtocolRoundTripsRequestIDsAndOperations),
    ("productionIOSEmbeddedQVACHostStatusBridgeReturnsMatchingRequestScopedResponse", productionIOSEmbeddedQVACHostStatusBridgeReturnsMatchingRequestScopedResponse),
    ("productionIOSEmbeddedQVACHostStatusBridgeRejectsMismatchedRequestIDResponse", productionIOSEmbeddedQVACHostStatusBridgeRejectsMismatchedRequestIDResponse),
    ("productionIOSEmbeddedQVACHostNotLinkedBridgeReturnsContentFreeUnavailableStatus", productionIOSEmbeddedQVACHostNotLinkedBridgeReturnsContentFreeUnavailableStatus),
    ("productionIOSEmbeddedQVACHostLinkedBridgeReturnsStartingStatusWithoutNotLinked", productionIOSEmbeddedQVACHostLinkedBridgeReturnsStartingStatusWithoutNotLinked),
    ("productionIOSEmbeddedQVACHostLinkedBridgeSendsRequestToHostResponseProvider", productionIOSEmbeddedQVACHostLinkedBridgeSendsRequestToHostResponseProvider),
    ("productionIOSEmbeddedQVACHostLinkedBridgeMapsStartupFailureToUnavailable", productionIOSEmbeddedQVACHostLinkedBridgeMapsStartupFailureToUnavailable),
    ("productionIOSEmbeddedQVACHostStatusResponseCodableDerivesDiagnosticCodeAndMessage", productionIOSEmbeddedQVACHostStatusResponseCodableDerivesDiagnosticCodeAndMessage),
    ("productionIOSEmbeddedQVACHostStatusResponseIgnoresDecodedDiagnosticCodeAndMessageFields", productionIOSEmbeddedQVACHostStatusResponseIgnoresDecodedDiagnosticCodeAndMessageFields),
    ("productionIOSQVACAdapterContractDefinesPhysicalEmbeddedExpoHost", productionIOSQVACAdapterContractDefinesPhysicalEmbeddedExpoHost),
    ("productionIOSQVACAdapterContractDefinesRequestScopedPayloadsAndEvents", productionIOSQVACAdapterContractDefinesRequestScopedPayloadsAndEvents),
    ("productionIOSQVACAdapterContractForbidsDelegatedRuntimeAuthorityAndHostedDependencies", productionIOSQVACAdapterContractForbidsDelegatedRuntimeAuthorityAndHostedDependencies),
    ("productionIOSQVACAdapterContractDocumentsLifecycleRisksAndPhysicalDeviceValidation", productionIOSQVACAdapterContractDocumentsLifecycleRisksAndPhysicalDeviceValidation),
    ("productionIOSQVACAdapterContractKeepsExpoLocalAndLimitedToSelectedContext", productionIOSQVACAdapterContractKeepsExpoLocalAndLimitedToSelectedContext),
    ("qvacPhysicalDeviceSmokePlanRejectsSimulatorAsValidationEnvironment", qvacPhysicalDeviceSmokePlanRejectsSimulatorAsValidationEnvironment),
    ("qvacPhysicalDeviceSmokePlanRejectsIOSVersionsBelowSeventeen", qvacPhysicalDeviceSmokePlanRejectsIOSVersionsBelowSeventeen),
    ("qvacPhysicalDeviceSmokePlanRequiresLocalOnlyExecution", qvacPhysicalDeviceSmokePlanRequiresLocalOnlyExecution),
    ("qvacPhysicalDeviceSmokePlanDoesNotRequireAppStorePublication", qvacPhysicalDeviceSmokePlanDoesNotRequireAppStorePublication),
    ("qvacPhysicalDeviceSmokeResultRecordsValidatedLocalModelResponseAndHostPath", qvacPhysicalDeviceSmokeResultRecordsValidatedLocalModelResponseAndHostPath),
    ("qvacPhysicalDeviceSmokeResultRejectsEmptyGeneratedText", qvacPhysicalDeviceSmokeResultRejectsEmptyGeneratedText),
    ("qvacPhysicalDeviceSmokeResultRequiresOfflineRepeatabilityCheck", qvacPhysicalDeviceSmokeResultRequiresOfflineRepeatabilityCheck),
    ("qvacPhysicalDeviceSmokeRunbookPreservesHITLChecklist", qvacPhysicalDeviceSmokeRunbookPreservesHITLChecklist),
    ("qvacDevelopmentAdapterAggregatesStreamingTokensAndProgress", qvacDevelopmentAdapterAggregatesStreamingTokensAndProgress),
    ("qvacDevelopmentAdapterSmokeSkipsWhenLocalConfigIsAbsent", qvacDevelopmentAdapterSmokeSkipsWhenLocalConfigIsAbsent),
    ("localProcessQVACAdapterTransportFramesRequestAndResponseLines", localProcessQVACAdapterTransportFramesRequestAndResponseLines),
    ("localProcessQVACAdapterTransportIgnoresOtherRequestIDsBeforeTerminalEvent", localProcessQVACAdapterTransportIgnoresOtherRequestIDsBeforeTerminalEvent),
    ("localProcessQVACAdapterTransportReturnsAfterTerminalEventWithoutWaitingForEOF", localProcessQVACAdapterTransportReturnsAfterTerminalEventWithoutWaitingForEOF),
    ("qvacDevelopmentAdapterPropagatesRequestScopedCancel", qvacDevelopmentAdapterPropagatesRequestScopedCancel),
    ("qvacDevelopmentAdapterMapsCancellationEventsByRequestID", qvacDevelopmentAdapterMapsCancellationEventsByRequestID),
    ("qvacDevelopmentAdapterMapsErrorEventsByRequestID", qvacDevelopmentAdapterMapsErrorEventsByRequestID),
    ("qvacDevelopmentAdapterMapsModelAvailabilityToRuntimeInventory", qvacDevelopmentAdapterMapsModelAvailabilityToRuntimeInventory),
    ("productionEmbeddedQVACHostAdapterAggregatesStreamedTokensIntoFinalText", productionEmbeddedQVACHostAdapterAggregatesStreamedTokensIntoFinalText),
    ("productionEmbeddedQVACHostAdapterFallsBackToCompletionTextWhenNoTokensStreamed", productionEmbeddedQVACHostAdapterFallsBackToCompletionTextWhenNoTokensStreamed),
    ("productionEmbeddedQVACHostAdapterIgnoresForeignRequestIDs", productionEmbeddedQVACHostAdapterIgnoresForeignRequestIDs),
    ("productionEmbeddedQVACHostAdapterMapsErrorEventToRequestFailed", productionEmbeddedQVACHostAdapterMapsErrorEventToRequestFailed),
    ("productionEmbeddedQVACHostAdapterMapsCanceledEventToCanceled", productionEmbeddedQVACHostAdapterMapsCanceledEventToCanceled),
    ("productionEmbeddedQVACHostAdapterThrowsMissingCompletionWhenNoCompletionEvent", productionEmbeddedQVACHostAdapterThrowsMissingCompletionWhenNoCompletionEvent),
    ("productionEmbeddedQVACHostAdapterMapsModelAvailabilityToRuntimeInventory", productionEmbeddedQVACHostAdapterMapsModelAvailabilityToRuntimeInventory),
    ("productionEmbeddedQVACHostAdapterModelAvailabilityErrorThrowsRequestFailed", productionEmbeddedQVACHostAdapterModelAvailabilityErrorThrowsRequestFailed),
    ("productionEmbeddedQVACHostAdapterSendsGeneralModeAndMappedContext", productionEmbeddedQVACHostAdapterSendsGeneralModeAndMappedContext),
    ("productionEmbeddedQVACHostAdapterModelAvailabilityThrowsMissingCompletionWhenNoAvailabilityEvent", productionEmbeddedQVACHostAdapterModelAvailabilityThrowsMissingCompletionWhenNoAvailabilityEvent),
    ("productionEmbeddedQVACHostAdapterAnswerThrowsUnexpectedCompletionWhenPayloadIsNotText", productionEmbeddedQVACHostAdapterAnswerThrowsUnexpectedCompletionWhenPayloadIsNotText),
    ("productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsText", productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsText),
    ("productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsNoteBodies", productionEmbeddedQVACHostAdapterSuggestedRelationshipsThrowsUnexpectedCompletionWhenPayloadIsNoteBodies),
    ("productionEmbeddedQVACHostAdapterGeneratedNoteBodiesThrowsUnexpectedCompletionWhenPayloadIsText", productionEmbeddedQVACHostAdapterGeneratedNoteBodiesThrowsUnexpectedCompletionWhenPayloadIsText),
    ("productionEmbeddedQVACHostAdapterModelAvailabilityDropsDefaultPointingAtUndownloadedProfile", productionEmbeddedQVACHostAdapterModelAvailabilityDropsDefaultPointingAtUndownloadedProfile),
    ("embeddedHostAnswerWireRequestEncodesProtocolTypeAndFieldsForJSResponder", embeddedHostAnswerWireRequestEncodesProtocolTypeAndFieldsForJSResponder),
    ("embeddedHostAnswerWireCompletedTextResponseRoundTripsAsQVACAdapterEvent", embeddedHostAnswerWireCompletedTextResponseRoundTripsAsQVACAdapterEvent),
    ("embeddedHostAnswerWireErrorResponseMapsToQVACAdapterErrorEvent", embeddedHostAnswerWireErrorResponseMapsToQVACAdapterErrorEvent)
]

var passed = 0

do {
    for (name, test) in tests {
        try await test()
        passed += 1
        print("PASS \(name)")
    }
    print("QVACRuntimeBehaviorTests: \(passed) passed")
} catch {
    print("FAIL \(error)")
    exit(1)
}
