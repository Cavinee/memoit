import Foundation

protocol NoteStore: AnyObject {
    func createNote(title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance?) throws -> Note
    func createNote(noteID: NoteID?, title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance?) throws -> Note
    func updateNoteBody(noteID: NoteID, body: String) throws -> Note
    func renameNote(noteID: NoteID, title: String) throws -> Note
    func setNotePinned(noteID: NoteID, isPinned: Bool) throws -> Note
    func moveNoteToTrash(noteID: NoteID) throws -> Note
    func restoreNoteFromTrash(noteID: NoteID) throws -> Note
    func permanentlyDeleteNote(noteID: NoteID) throws
    func replaceNote(_ note: Note) throws -> Note
    func note(withID noteID: NoteID) throws -> Note?
    func note(titled title: String) throws -> Note?
    func listNotes() throws -> [Note]
    func listNotes(includeTrash: Bool) throws -> [Note]
}

extension NoteStore {
    func createNote(title: String, body: String, creationProvenance: CreationProvenance) throws -> Note {
        try createNote(title: title, body: body, creationProvenance: creationProvenance, importProvenance: nil)
    }
}

final class InMemoryNoteStore: NoteStore {
    private var notesByID: [NoteID: Note] = [:]
    private var noteOrder: [NoteID] = []
    private var nextNoteNumber = 1
    private let titleDisambiguator = TitleDisambiguator()
    private let clock: () -> Date

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
    }

    func createNote(title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance? = nil) throws -> Note {
        try createNote(noteID: nil, title: title, body: body, creationProvenance: creationProvenance, importProvenance: importProvenance)
    }

    func createNote(noteID requestedNoteID: NoteID?, title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance? = nil) throws -> Note {
        let noteID = requestedNoteID.flatMap { notesByID[$0] == nil ? $0 : nil } ?? nextGeneratedNoteID()
        let noteTitle = titleDisambiguator.disambiguatedTitle(
            requestedTitle: title,
            existingTitles: Set(notesByID.values.map(\.title))
        )
        let note = Note(
            id: noteID,
            title: noteTitle,
            body: body,
            creationProvenance: creationProvenance,
            importProvenance: importProvenance,
            isPlaceholder: creationProvenance == .placeholderCreated,
            lastEditedAt: timestampNow()
        )
        notesByID[noteID] = note
        noteOrder.append(noteID)
        return note
    }

    private func nextGeneratedNoteID() -> NoteID {
        while notesByID[NoteID("note-\(nextNoteNumber)")] != nil {
            nextNoteNumber += 1
        }
        let noteID = NoteID("note-\(nextNoteNumber)")
        nextNoteNumber += 1
        return noteID
    }

    func updateNoteBody(noteID: NoteID, body: String) throws -> Note {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }

        let updated = Note(
            id: existing.id,
            title: existing.title,
            body: body,
            creationProvenance: existing.creationProvenance,
            importProvenance: existing.importProvenance,
            isPlaceholder: existing.isPlaceholder && body.isEmpty,
            isTrashed: existing.isTrashed,
            isPinned: existing.isPinned,
            lastEditedAt: timestampNow()
        )
        notesByID[noteID] = updated
        return updated
    }

    func renameNote(noteID: NoteID, title: String) throws -> Note {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }

        let noteTitle = titleDisambiguator.disambiguatedTitle(
            requestedTitle: title,
            existingTitles: Set(notesByID.values.filter { $0.id != noteID }.map(\.title))
        )
        let renamed = Note(
            id: existing.id,
            title: noteTitle,
            body: existing.body,
            creationProvenance: existing.creationProvenance,
            importProvenance: existing.importProvenance,
            isPlaceholder: existing.isPlaceholder,
            isTrashed: existing.isTrashed,
            isPinned: existing.isPinned,
            lastEditedAt: timestampNow()
        )
        notesByID[noteID] = renamed
        return renamed
    }

    func setNotePinned(noteID: NoteID, isPinned: Bool) throws -> Note {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }

        let updated = Note(
            id: existing.id,
            title: existing.title,
            body: existing.body,
            creationProvenance: existing.creationProvenance,
            importProvenance: existing.importProvenance,
            isPlaceholder: existing.isPlaceholder,
            isTrashed: existing.isTrashed,
            isPinned: isPinned,
            lastEditedAt: existing.lastEditedAt
        )
        notesByID[noteID] = updated
        return updated
    }

    func moveNoteToTrash(noteID: NoteID) throws -> Note {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }

        let trashed = Note(
            id: existing.id,
            title: existing.title,
            body: existing.body,
            creationProvenance: existing.creationProvenance,
            importProvenance: existing.importProvenance,
            isPlaceholder: existing.isPlaceholder,
            isTrashed: true,
            isPinned: existing.isPinned,
            lastEditedAt: existing.lastEditedAt
        )
        notesByID[noteID] = trashed
        return trashed
    }

    func restoreNoteFromTrash(noteID: NoteID) throws -> Note {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }
        guard existing.isTrashed else {
            throw RuntimeError.noteNotInTrash(noteID)
        }

        let restored = Note(
            id: existing.id,
            title: existing.title,
            body: existing.body,
            creationProvenance: existing.creationProvenance,
            importProvenance: existing.importProvenance,
            isPlaceholder: existing.isPlaceholder,
            isTrashed: false,
            isPinned: existing.isPinned,
            lastEditedAt: existing.lastEditedAt
        )
        notesByID[noteID] = restored
        return restored
    }

    func permanentlyDeleteNote(noteID: NoteID) throws {
        guard let existing = notesByID[noteID] else {
            throw RuntimeError.noteNotFound(noteID)
        }
        guard existing.isTrashed else {
            throw RuntimeError.noteNotInTrash(noteID)
        }

        notesByID[noteID] = nil
        noteOrder.removeAll { $0 == noteID }
    }

    func replaceNote(_ note: Note) throws -> Note {
        guard notesByID[note.id] != nil else {
            throw RuntimeError.noteNotFound(note.id)
        }

        notesByID[note.id] = note
        return note
    }

    func note(withID noteID: NoteID) throws -> Note? {
        notesByID[noteID]
    }

    func note(titled title: String) throws -> Note? {
        notesByID.values.first { $0.title == title && !$0.isTrashed }
    }

    func listNotes() throws -> [Note] {
        try listNotes(includeTrash: false)
    }

    func listNotes(includeTrash: Bool) throws -> [Note] {
        let notes = noteOrder.compactMap { notesByID[$0] }
        return includeTrash ? notes : notes.filter { !$0.isTrashed }
    }

    private func timestampNow() -> Date {
        storageStableTimestamp(clock())
    }
}

func storageStableTimestamp(_ date: Date) -> Date {
    Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1_000).rounded() / 1_000)
}
