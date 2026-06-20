import QVACRuntime
import Darwin

struct HarnessFailure: Error, CustomStringConvertible {
    let description: String
}

func note(from result: RuntimeCommandResult) throws -> Note {
    switch result {
    case .createdNote(let note), .updatedNote(let note), .renamedNote(let note):
        return note
    case .movedNoteToTrash(let note, _):
        return note
    case .restoredNote(let note):
        return note
    case .discardedEmptyNote, .permanentlyDeletedNote, .ranIndexingJobs, .importedMarkdown, .suggestedRelationships, .createdAcceptedRelationship, .recordedLocalModelProfile, .updatedModelInventory, .deletedAISessionHistoryEntry, .savedAIResponse, .setAIEditingPermission, .aiWriteWorkflow, .acceptedDraftChange, .canceledDraftChange, .beganIncompleteAIOperation, .simulatedCrashRestart, .configuredAIOperationCommitFailure, .reversedAIOperation:
        throw HarnessFailure(description: "expected Note command result")
    }
}

func notes(from result: RuntimeQueryResult) throws -> [Note] {
    switch result {
    case .notes(let notes):
        return notes
    default:
        throw HarnessFailure(description: "expected Note list query result")
    }
}

do {
    let runtime = RuntimeCoreHarness.makeInMemory()

    let first = try note(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "# Daily Note\n\nRaw **Markdown** body.",
        creationProvenance: .userCreated
    ))))

    let duplicate = try note(from: runtime.execute(.createNote(.init(
        title: "Daily Note",
        body: "- captured locally",
        creationProvenance: .userCreated
    ))))

    let renamed = try note(from: runtime.execute(.renameNote(.init(
        noteID: first.id,
        title: "Runtime Core"
    ))))

    let updated = try note(from: runtime.execute(.updateNoteBody(.init(
        noteID: renamed.id,
        body: "# Runtime Core\n\n[[Daily Note (2)]] remains raw Markdown."
    ))))

    let listedNotes = try notes(from: runtime.query(.notes))

    print("QVAC Runtime Core Harness")
    print("created \(first.id) \(first.title)")
    print("created \(duplicate.id) \(duplicate.title)")
    print("renamed \(renamed.id) \(renamed.title)")
    print("updated \(updated.id) body:")
    print(updated.body)
    print("notes:")

    for note in listedNotes {
        print("- \(note.id) | \(note.title) | \(note.creationProvenance.rawValue)")
    }
} catch {
    print("Harness failed: \(error)")
    exit(1)
}
