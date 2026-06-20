import Foundation
import SQLite3

public final class RuntimeNoteIDMappingStore {
    private let database: OpaquePointer?

    public init(storageURL: URL) throws {
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
            throw RuntimeNoteIDMappingStoreError.openFailed(message)
        }

        database = openedDatabase
        try execute("PRAGMA foreign_keys = ON")
        try execute("""
        CREATE TABLE IF NOT EXISTS runtime_note_id_mappings (
            runtime_id TEXT PRIMARY KEY,
            app_id TEXT NOT NULL UNIQUE
        )
        """)
    }

    deinit {
        sqlite3_close(database)
    }

    public func appID(for noteID: NoteID) throws -> UUID {
        if let existing = try appID(mappedFrom: noteID) {
            return existing
        }

        let appID = UUID(uuidString: noteID.rawValue) ?? UUID()
        try remember(noteID: noteID, appID: appID)
        return appID
    }

    public func noteID(for appID: UUID) throws -> NoteID? {
        try noteID(mappedFrom: appID)
    }

    public func remember(noteID: NoteID, appID: UUID) throws {
        let statement = try prepare("""
        INSERT INTO runtime_note_id_mappings (runtime_id, app_id)
        VALUES (?, ?)
        ON CONFLICT(runtime_id) DO UPDATE SET app_id = excluded.app_id
        """)
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        try bind(appID.uuidString, at: 2, in: statement)
        try stepDone(statement)
    }

    public func forget(noteID: NoteID) throws {
        let statement = try prepare("DELETE FROM runtime_note_id_mappings WHERE runtime_id = ?")
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        try stepDone(statement)
    }

    private func appID(mappedFrom noteID: NoteID) throws -> UUID? {
        let statement = try prepare("SELECT app_id FROM runtime_note_id_mappings WHERE runtime_id = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        guard let rawValue = try stepString(statement) else {
            return nil
        }
        guard let appID = UUID(uuidString: rawValue) else {
            throw RuntimeNoteIDMappingStoreError.invalidStoredAppID(rawValue)
        }
        return appID
    }

    private func noteID(mappedFrom appID: UUID) throws -> NoteID? {
        let statement = try prepare("SELECT runtime_id FROM runtime_note_id_mappings WHERE app_id = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        try bind(appID.uuidString, at: 1, in: statement)
        return try stepString(statement).map(NoteID.init)
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw RuntimeNoteIDMappingStoreError.executionFailed(sqliteMessage())
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RuntimeNoteIDMappingStoreError.prepareFailed(sqliteMessage())
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, sqliteTransient)
        }
        guard result == SQLITE_OK else {
            throw RuntimeNoteIDMappingStoreError.bindFailed(sqliteMessage())
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RuntimeNoteIDMappingStoreError.stepFailed(sqliteMessage())
        }
    }

    private func stepString(_ statement: OpaquePointer?) throws -> String? {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            guard let value = sqlite3_column_text(statement, 0) else {
                return nil
            }
            return String(cString: value)
        }
        if result == SQLITE_DONE {
            return nil
        }
        throw RuntimeNoteIDMappingStoreError.stepFailed(sqliteMessage())
    }

    private func sqliteMessage() -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

private enum RuntimeNoteIDMappingStoreError: Error, Equatable {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case invalidStoredAppID(String)
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
