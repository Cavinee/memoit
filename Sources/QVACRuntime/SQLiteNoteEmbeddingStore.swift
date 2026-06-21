import Foundation
import SQLite3

/// One persisted embedding row: the vector plus the staleness metadata used to decide
/// whether it can be reused on rebuild (`modelID` and `contentHash` must both match the
/// current note/provider) instead of re-embedding.
struct StoredNoteEmbedding {
    let noteID: NoteID
    let modelID: String
    let contentHash: String
    let vector: [Float]
}

/// CRUD persistence for note embedding vectors. Abstracted (like `NoteStore`/`GraphStore`)
/// so the in-memory rebuild path can pass `nil` and the SQLite-backed path can persist.
/// Staleness orchestration lives in `NoteEmbeddingIndex`, not here — this is storage only.
protocol NoteEmbeddingStore {
    func loadAll() throws -> [NoteID: StoredNoteEmbedding]
    func upsert(_ embedding: StoredNoteEmbedding) throws
    /// Drops every stored row whose note ID is not in `noteIDs` (deleted/trashed notes).
    func deleteAll(exceptNoteIDs noteIDs: Set<NoteID>) throws
}

/// SQLite-backed `NoteEmbeddingStore`. Opens the SAME shared database file as the note and
/// graph stores and owns the `note_embeddings` table, storing each vector as a contiguous
/// little-endian Float32 BLOB. Mirrors `SQLiteNoteStore`'s open flags, statement helpers,
/// and error handling.
final class SQLiteNoteEmbeddingStore: NoteEmbeddingStore {
    private let database: OpaquePointer?

    init(storageURL: URL) throws {
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
            throw SQLiteNoteEmbeddingStoreError.openFailed(message)
        }

        database = openedDatabase
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = DELETE")
        try execute("""
        CREATE TABLE IF NOT EXISTS note_embeddings (
            noteID TEXT PRIMARY KEY,
            modelId TEXT NOT NULL,
            dims INTEGER NOT NULL,
            vector BLOB NOT NULL,
            contentHash TEXT NOT NULL
        )
        """)
    }

    deinit {
        sqlite3_close(database)
    }

    func loadAll() throws -> [NoteID: StoredNoteEmbedding] {
        let statement = try prepare("SELECT noteID, modelId, dims, vector, contentHash FROM note_embeddings")
        defer { sqlite3_finalize(statement) }

        var embeddings: [NoteID: StoredNoteEmbedding] = [:]
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                let noteID = NoteID(stringColumn(0, in: statement))
                let modelID = stringColumn(1, in: statement)
                let dims = Int(sqlite3_column_int(statement, 2))
                let vector = floatVectorColumn(3, expectedCount: dims, in: statement)
                let contentHash = stringColumn(4, in: statement)
                embeddings[noteID] = StoredNoteEmbedding(
                    noteID: noteID,
                    modelID: modelID,
                    contentHash: contentHash,
                    vector: vector
                )
            } else if result == SQLITE_DONE {
                return embeddings
            } else {
                throw SQLiteNoteEmbeddingStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    func upsert(_ embedding: StoredNoteEmbedding) throws {
        let statement = try prepare("""
        INSERT INTO note_embeddings (noteID, modelId, dims, vector, contentHash)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(noteID) DO UPDATE SET
            modelId = excluded.modelId,
            dims = excluded.dims,
            vector = excluded.vector,
            contentHash = excluded.contentHash
        """)
        defer { sqlite3_finalize(statement) }
        try bind(embedding.noteID.rawValue, at: 1, in: statement)
        try bind(embedding.modelID, at: 2, in: statement)
        try bind(Int32(embedding.vector.count), at: 3, in: statement)
        try bind(embedding.vector, at: 4, in: statement)
        try bind(embedding.contentHash, at: 5, in: statement)
        try stepDone(statement)
    }

    func deleteAll(exceptNoteIDs noteIDs: Set<NoteID>) throws {
        guard !noteIDs.isEmpty else {
            try execute("DELETE FROM note_embeddings")
            return
        }

        let placeholders = Array(repeating: "?", count: noteIDs.count).joined(separator: ", ")
        let statement = try prepare("DELETE FROM note_embeddings WHERE noteID NOT IN (\(placeholders))")
        defer { sqlite3_finalize(statement) }
        for (offset, noteID) in noteIDs.enumerated() {
            try bind(noteID.rawValue, at: Int32(offset + 1), in: statement)
        }
        try stepDone(statement)
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteNoteEmbeddingStoreError.executionFailed(sqliteMessage())
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteNoteEmbeddingStoreError.prepareFailed(sqliteMessage())
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, sqliteEmbeddingTransient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteNoteEmbeddingStoreError.bindFailed(sqliteMessage())
        }
    }

    private func bind(_ value: Int32, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int(statement, index, value) == SQLITE_OK else {
            throw SQLiteNoteEmbeddingStoreError.bindFailed(sqliteMessage())
        }
    }

    private func bind(_ value: [Float], at index: Int32, in statement: OpaquePointer?) throws {
        let result = value.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(statement, index, rawBuffer.baseAddress, Int32(rawBuffer.count), sqliteEmbeddingTransient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteNoteEmbeddingStoreError.bindFailed(sqliteMessage())
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteNoteEmbeddingStoreError.stepFailed(sqliteMessage())
        }
    }

    private func stringColumn(_ index: Int32, in statement: OpaquePointer?) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    /// Reads a BLOB column back into `[Float]`. Copies the bytes out before the statement
    /// is finalized (the pointer from `sqlite3_column_blob` is only valid until then).
    private func floatVectorColumn(_ index: Int32, expectedCount: Int, in statement: OpaquePointer?) -> [Float] {
        let byteCount = Int(sqlite3_column_bytes(statement, index))
        guard byteCount > 0, let pointer = sqlite3_column_blob(statement, index) else {
            return []
        }
        let floatCount = byteCount / MemoryLayout<Float>.size
        var vector = [Float](repeating: 0, count: floatCount)
        vector.withUnsafeMutableBytes { destination in
            destination.copyMemory(from: UnsafeRawBufferPointer(start: pointer, count: floatCount * MemoryLayout<Float>.size))
        }
        return vector
    }

    private func sqliteMessage() -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

private let sqliteEmbeddingTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteNoteEmbeddingStoreError: Error, Equatable {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
}
