import Foundation
import SQLite3

final class SQLiteNoteStore: NoteStore {
    private let database: OpaquePointer?
    private let titleDisambiguator = TitleDisambiguator()
    private let clock: () -> Date

    init(storageURL: URL, clock: @escaping () -> Date = Date.init) throws {
        self.clock = clock

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var openedDatabase: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(storageURL.path, &openedDatabase, flags, nil) == SQLITE_OK else {
            let message = openedDatabase.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite open error"
            if let openedDatabase {
                sqlite3_close(openedDatabase)
            }
            throw SQLiteNoteStoreError.openFailed(message)
        }

        database = openedDatabase
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = DELETE")
        try execute("""
        CREATE TABLE IF NOT EXISTS notes (
            position INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            creation_provenance TEXT NOT NULL,
            import_source_path TEXT,
            is_placeholder INTEGER NOT NULL,
            is_trashed INTEGER NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            last_edited_at REAL NOT NULL DEFAULT 0
        )
        """)
        try ensureColumn("is_pinned", definition: "INTEGER NOT NULL DEFAULT 0")
        try ensureColumn("last_edited_at", definition: "REAL NOT NULL DEFAULT 0")
        try execute("""
        CREATE TABLE IF NOT EXISTS runtime_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """)
    }

    deinit {
        sqlite3_close(database)
    }

    func createNote(title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance? = nil) throws -> Note {
        try createNote(noteID: nil, title: title, body: body, creationProvenance: creationProvenance, importProvenance: importProvenance)
    }

    func createNote(noteID requestedNoteID: NoteID?, title: String, body: String, creationProvenance: CreationProvenance, importProvenance: ImportProvenance? = nil) throws -> Note {
        try transaction {
            let noteID = try requestedNoteID.flatMap { try noteExists($0) ? nil : $0 } ?? nextGeneratedNoteID()
            let noteTitle = titleDisambiguator.disambiguatedTitle(
                requestedTitle: title,
                existingTitles: Set(try allNotes(includeTrash: true).map(\.title))
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
            try insert(note)
            return note
        }
    }

    func updateNoteBody(noteID: NoteID, body: String) throws -> Note {
        guard let existing = try fetchNote(withID: noteID) else {
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
        try updateStoredNote(updated)
        return updated
    }

    func renameNote(noteID: NoteID, title: String) throws -> Note {
        guard let existing = try fetchNote(withID: noteID) else {
            throw RuntimeError.noteNotFound(noteID)
        }

        let noteTitle = titleDisambiguator.disambiguatedTitle(
            requestedTitle: title,
            existingTitles: Set(try allNotes(includeTrash: true).filter { $0.id != noteID }.map(\.title))
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
        try updateStoredNote(renamed)
        return renamed
    }

    func setNotePinned(noteID: NoteID, isPinned: Bool) throws -> Note {
        guard let existing = try fetchNote(withID: noteID) else {
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
        try updateStoredNote(updated)
        return updated
    }

    func moveNoteToTrash(noteID: NoteID) throws -> Note {
        guard let existing = try fetchNote(withID: noteID) else {
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
        try updateStoredNote(trashed)
        return trashed
    }

    func restoreNoteFromTrash(noteID: NoteID) throws -> Note {
        guard let existing = try fetchNote(withID: noteID) else {
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
        try updateStoredNote(restored)
        return restored
    }

    func permanentlyDeleteNote(noteID: NoteID) throws {
        guard let existing = try fetchNote(withID: noteID) else {
            throw RuntimeError.noteNotFound(noteID)
        }
        guard existing.isTrashed else {
            throw RuntimeError.noteNotInTrash(noteID)
        }

        let statement = try prepare("DELETE FROM notes WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        try stepDone(statement)
    }

    func replaceNote(_ note: Note) throws -> Note {
        guard try noteExists(note.id) else {
            throw RuntimeError.noteNotFound(note.id)
        }

        try updateStoredNote(note)
        return note
    }

    func note(withID noteID: NoteID) throws -> Note? {
        try fetchNote(withID: noteID)
    }

    func note(titled title: String) throws -> Note? {
        let statement = try prepare("""
        SELECT id, title, body, creation_provenance, import_source_path, is_placeholder, is_trashed, is_pinned, last_edited_at
        FROM notes
        WHERE title = ? AND is_trashed = 0
        ORDER BY position ASC
        LIMIT 1
        """)
        defer { sqlite3_finalize(statement) }
        try bind(title, at: 1, in: statement)
        return try stepNote(statement)
    }

    func listNotes() throws -> [Note] {
        try listNotes(includeTrash: false)
    }

    func listNotes(includeTrash: Bool) throws -> [Note] {
        try allNotes(includeTrash: includeTrash)
    }

    private func insert(_ note: Note) throws {
        let statement = try prepare("""
        INSERT INTO notes (
            id,
            title,
            body,
            creation_provenance,
            import_source_path,
            is_placeholder,
            is_trashed,
            is_pinned,
            last_edited_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """)
        defer { sqlite3_finalize(statement) }
        try bind(note.id.rawValue, at: 1, in: statement)
        try bind(note.title, at: 2, in: statement)
        try bind(note.body, at: 3, in: statement)
        try bind(note.creationProvenance.rawValue, at: 4, in: statement)
        try bind(note.importProvenance?.sourcePath, at: 5, in: statement)
        try bind(note.isPlaceholder, at: 6, in: statement)
        try bind(note.isTrashed, at: 7, in: statement)
        try bind(note.isPinned, at: 8, in: statement)
        try bind(note.lastEditedAt, at: 9, in: statement)
        try stepDone(statement)
    }

    private func updateStoredNote(_ note: Note) throws {
        let statement = try prepare("""
        UPDATE notes
        SET title = ?,
            body = ?,
            creation_provenance = ?,
            import_source_path = ?,
            is_placeholder = ?,
            is_trashed = ?,
            is_pinned = ?,
            last_edited_at = ?
        WHERE id = ?
        """)
        defer { sqlite3_finalize(statement) }
        try bind(note.title, at: 1, in: statement)
        try bind(note.body, at: 2, in: statement)
        try bind(note.creationProvenance.rawValue, at: 3, in: statement)
        try bind(note.importProvenance?.sourcePath, at: 4, in: statement)
        try bind(note.isPlaceholder, at: 5, in: statement)
        try bind(note.isTrashed, at: 6, in: statement)
        try bind(note.isPinned, at: 7, in: statement)
        try bind(note.lastEditedAt, at: 8, in: statement)
        try bind(note.id.rawValue, at: 9, in: statement)
        try stepDone(statement)
    }

    private func fetchNote(withID noteID: NoteID) throws -> Note? {
        let statement = try prepare("""
        SELECT id, title, body, creation_provenance, import_source_path, is_placeholder, is_trashed, is_pinned, last_edited_at
        FROM notes
        WHERE id = ?
        LIMIT 1
        """)
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        return try stepNote(statement)
    }

    private func noteExists(_ noteID: NoteID) throws -> Bool {
        let statement = try prepare("SELECT 1 FROM notes WHERE id = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        return try stepExists(statement)
    }

    private func allNotes(includeTrash: Bool) throws -> [Note] {
        let statement = try prepare("""
        SELECT id, title, body, creation_provenance, import_source_path, is_placeholder, is_trashed, is_pinned, last_edited_at
        FROM notes
        \(includeTrash ? "" : "WHERE is_trashed = 0")
        ORDER BY position ASC
        """)
        defer { sqlite3_finalize(statement) }

        var notes: [Note] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                notes.append(try readNote(from: statement))
            } else if result == SQLITE_DONE {
                return notes
            } else {
                throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    private func nextGeneratedNoteID() throws -> NoteID {
        var nextNoteNumber = try currentGeneratedNoteSequence() + 1
        while try noteExists(NoteID("note-\(nextNoteNumber)")) {
            nextNoteNumber += 1
        }
        try setGeneratedNoteSequence(nextNoteNumber)
        return NoteID("note-\(nextNoteNumber)")
    }

    private func currentGeneratedNoteSequence() throws -> Int {
        let statement = try prepare("SELECT value FROM runtime_metadata WHERE key = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        try bind("generated_note_sequence", at: 1, in: statement)
        if let stored = try stepString(statement), let value = Int(stored) {
            return value
        }

        let maxExisting = try maxExistingGeneratedNoteNumber()
        try setGeneratedNoteSequence(maxExisting)
        return maxExisting
    }

    private func setGeneratedNoteSequence(_ value: Int) throws {
        let statement = try prepare("""
        INSERT INTO runtime_metadata (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        """)
        defer { sqlite3_finalize(statement) }
        try bind("generated_note_sequence", at: 1, in: statement)
        try bind(String(value), at: 2, in: statement)
        try stepDone(statement)
    }

    private func maxExistingGeneratedNoteNumber() throws -> Int {
        let statement = try prepare("SELECT id FROM notes")
        defer { sqlite3_finalize(statement) }

        var maxNoteNumber = 0
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                let rawValue = stringColumn(0, in: statement)
                if rawValue.hasPrefix("note-"), let number = Int(rawValue.dropFirst("note-".count)) {
                    maxNoteNumber = max(maxNoteNumber, number)
                }
            } else if result == SQLITE_DONE {
                return maxNoteNumber
            } else {
                throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    private func transaction<Result>(_ work: () throws -> Result) throws -> Result {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try work()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteNoteStoreError.executionFailed(sqliteMessage())
        }
    }

    private func ensureColumn(_ name: String, definition: String) throws {
        let statement = try prepare("PRAGMA table_info(notes)")
        defer { sqlite3_finalize(statement) }

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                if stringColumn(1, in: statement) == name {
                    return
                }
            } else if result == SQLITE_DONE {
                try execute("ALTER TABLE notes ADD COLUMN \(name) \(definition)")
                return
            } else {
                throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteNoteStoreError.prepareFailed(sqliteMessage())
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, sqliteTransient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteNoteStoreError.bindFailed(sqliteMessage())
        }
    }

    private func bind(_ value: String?, at index: Int32, in statement: OpaquePointer?) throws {
        if let value {
            try bind(value, at: index, in: statement)
        } else if sqlite3_bind_null(statement, index) != SQLITE_OK {
            throw SQLiteNoteStoreError.bindFailed(sqliteMessage())
        }
    }

    private func bind(_ value: Bool, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int(statement, index, value ? 1 : 0) == SQLITE_OK else {
            throw SQLiteNoteStoreError.bindFailed(sqliteMessage())
        }
    }

    private func bind(_ value: Date, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value.timeIntervalSince1970) == SQLITE_OK else {
            throw SQLiteNoteStoreError.bindFailed(sqliteMessage())
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
        }
    }

    private func stepExists(_ statement: OpaquePointer?) throws -> Bool {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return true
        }
        if result == SQLITE_DONE {
            return false
        }
        throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
    }

    private func stepNote(_ statement: OpaquePointer?) throws -> Note? {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return try readNote(from: statement)
        }
        if result == SQLITE_DONE {
            return nil
        }
        throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
    }

    private func stepString(_ statement: OpaquePointer?) throws -> String? {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return stringColumn(0, in: statement)
        }
        if result == SQLITE_DONE {
            return nil
        }
        throw SQLiteNoteStoreError.stepFailed(sqliteMessage())
    }

    private func readNote(from statement: OpaquePointer?) throws -> Note {
        let creationProvenanceRawValue = stringColumn(3, in: statement)
        guard let creationProvenance = CreationProvenance(rawValue: creationProvenanceRawValue) else {
            throw SQLiteNoteStoreError.invalidCreationProvenance(creationProvenanceRawValue)
        }

        return Note(
            id: NoteID(stringColumn(0, in: statement)),
            title: stringColumn(1, in: statement),
            body: stringColumn(2, in: statement),
            creationProvenance: creationProvenance,
            importProvenance: optionalStringColumn(4, in: statement).map(ImportProvenance.init(sourcePath:)),
            isPlaceholder: boolColumn(5, in: statement),
            isTrashed: boolColumn(6, in: statement),
            isPinned: boolColumn(7, in: statement),
            lastEditedAt: dateColumn(8, in: statement)
        )
    }

    private func stringColumn(_ index: Int32, in statement: OpaquePointer?) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    private func optionalStringColumn(_ index: Int32, in statement: OpaquePointer?) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return stringColumn(index, in: statement)
    }

    private func boolColumn(_ index: Int32, in statement: OpaquePointer?) -> Bool {
        sqlite3_column_int(statement, index) != 0
    }

    private func dateColumn(_ index: Int32, in statement: OpaquePointer?) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func sqliteMessage() -> String {
        String(cString: sqlite3_errmsg(database))
    }

    private func timestampNow() -> Date {
        storageStableTimestamp(clock())
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteNoteStoreError: Error, Equatable {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case invalidCreationProvenance(String)
}
