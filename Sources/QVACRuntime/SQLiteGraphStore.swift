import Foundation
import SQLite3

final class SQLiteGraphStore: GraphStore {
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
            throw SQLiteGraphStoreError.openFailed(message)
        }

        database = openedDatabase
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = DELETE")
        try execute("""
        CREATE TABLE IF NOT EXISTS explicit_links (
            position INTEGER PRIMARY KEY AUTOINCREMENT,
            source_note_id TEXT NOT NULL,
            target_note_id TEXT NOT NULL,
            snippet TEXT NOT NULL
        )
        """)
        try execute("CREATE INDEX IF NOT EXISTS explicit_links_source_index ON explicit_links(source_note_id)")
        try execute("CREATE INDEX IF NOT EXISTS explicit_links_target_index ON explicit_links(target_note_id)")
        try execute("""
        CREATE TABLE IF NOT EXISTS accepted_relationships (
            position INTEGER PRIMARY KEY AUTOINCREMENT,
            source_note_id TEXT NOT NULL,
            target_note_id TEXT NOT NULL
        )
        """)
        try execute("CREATE INDEX IF NOT EXISTS accepted_relationships_source_index ON accepted_relationships(source_note_id)")
    }

    deinit {
        sqlite3_close(database)
    }

    func isEmpty() throws -> Bool {
        try rowCount(in: "explicit_links") == 0 && rowCount(in: "accepted_relationships") == 0
    }

    func replaceExplicitLinks(from sourceNoteID: NoteID, with explicitLinks: [ExplicitLink]) throws {
        try transaction {
            let deleteStatement = try prepare("DELETE FROM explicit_links WHERE source_note_id = ?")
            defer { sqlite3_finalize(deleteStatement) }
            try bind(sourceNoteID.rawValue, at: 1, in: deleteStatement)
            try stepDone(deleteStatement)

            for link in explicitLinks {
                let insertStatement = try prepare("""
                INSERT INTO explicit_links (source_note_id, target_note_id, snippet)
                VALUES (?, ?, ?)
                """)
                defer { sqlite3_finalize(insertStatement) }
                try bind(link.sourceNoteID.rawValue, at: 1, in: insertStatement)
                try bind(link.targetNoteID.rawValue, at: 2, in: insertStatement)
                try bind(link.snippet, at: 3, in: insertStatement)
                try stepDone(insertStatement)
            }
        }
    }

    func explicitLinks(from sourceNoteID: NoteID) throws -> [ExplicitLink] {
        let statement = try prepare("""
        SELECT source_note_id, target_note_id, snippet
        FROM explicit_links
        WHERE source_note_id = ?
        ORDER BY position ASC
        """)
        defer { sqlite3_finalize(statement) }
        try bind(sourceNoteID.rawValue, at: 1, in: statement)
        return try readExplicitLinks(statement)
    }

    func sourceNoteIDsWithExplicitLinks(to targetNoteID: NoteID) throws -> [NoteID] {
        let statement = try prepare("""
        SELECT source_note_id
        FROM explicit_links
        WHERE target_note_id = ?
        ORDER BY position ASC
        """)
        defer { sqlite3_finalize(statement) }
        try bind(targetNoteID.rawValue, at: 1, in: statement)

        var seen = Set<NoteID>()
        var sourceNoteIDs: [NoteID] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                let sourceNoteID = NoteID(stringColumn(0, in: statement))
                if seen.insert(sourceNoteID).inserted {
                    sourceNoteIDs.append(sourceNoteID)
                }
            } else if result == SQLITE_DONE {
                return sourceNoteIDs
            } else {
                throw SQLiteGraphStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    func explicitLinkTargets(from sourceNoteID: NoteID) throws -> [NoteID] {
        var seen = Set<NoteID>()
        return try explicitLinks(from: sourceNoteID).compactMap { link in
            seen.insert(link.targetNoteID).inserted ? link.targetNoteID : nil
        }
    }

    func removeExplicitLinks(involving noteID: NoteID) throws {
        let statement = try prepare("""
        DELETE FROM explicit_links
        WHERE source_note_id = ? OR target_note_id = ?
        """)
        defer { sqlite3_finalize(statement) }
        try bind(noteID.rawValue, at: 1, in: statement)
        try bind(noteID.rawValue, at: 2, in: statement)
        try stepDone(statement)
    }

    func backlinks(to targetNoteID: NoteID, sourceNote: (NoteID) throws -> Note?) throws -> [Backlink] {
        let statement = try prepare("""
        SELECT source_note_id, target_note_id, snippet
        FROM explicit_links
        WHERE target_note_id = ?
        ORDER BY position ASC
        """)
        defer { sqlite3_finalize(statement) }
        try bind(targetNoteID.rawValue, at: 1, in: statement)

        return try readExplicitLinks(statement).compactMap { link in
            guard let source = try sourceNote(link.sourceNoteID) else {
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

    func createAcceptedRelationship(sourceNoteID: NoteID, targetNoteID: NoteID) throws -> AcceptedRelationship {
        let relationship = AcceptedRelationship(sourceNoteID: sourceNoteID, targetNoteID: targetNoteID)
        let statement = try prepare("""
        INSERT INTO accepted_relationships (source_note_id, target_note_id)
        VALUES (?, ?)
        """)
        defer { sqlite3_finalize(statement) }
        try bind(sourceNoteID.rawValue, at: 1, in: statement)
        try bind(targetNoteID.rawValue, at: 2, in: statement)
        try stepDone(statement)
        return relationship
    }

    func acceptedRelationshipTargets(from sourceNoteID: NoteID) throws -> [NoteID] {
        var seen = Set<NoteID>()
        return try listAcceptedRelationships().compactMap { relationship in
            guard relationship.sourceNoteID == sourceNoteID else {
                return nil
            }

            return seen.insert(relationship.targetNoteID).inserted ? relationship.targetNoteID : nil
        }
    }

    func listAcceptedRelationships() throws -> [AcceptedRelationship] {
        let statement = try prepare("""
        SELECT source_note_id, target_note_id
        FROM accepted_relationships
        ORDER BY position ASC
        """)
        defer { sqlite3_finalize(statement) }

        var relationships: [AcceptedRelationship] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                relationships.append(AcceptedRelationship(
                    sourceNoteID: NoteID(stringColumn(0, in: statement)),
                    targetNoteID: NoteID(stringColumn(1, in: statement))
                ))
            } else if result == SQLITE_DONE {
                return relationships
            } else {
                throw SQLiteGraphStoreError.stepFailed(sqliteMessage())
            }
        }
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
            for link in try explicitLinks(from: note.id) where activeNoteIDs.contains(link.targetNoteID) {
                appendEdge(TrustedGraphEdge(
                    sourceNoteID: link.sourceNoteID,
                    targetNoteID: link.targetNoteID,
                    provenance: .explicitLink
                ))
            }
        }

        for relationship in try listAcceptedRelationships() where activeNoteIDs.contains(relationship.sourceNoteID) && activeNoteIDs.contains(relationship.targetNoteID) {
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

    private func readExplicitLinks(_ statement: OpaquePointer?) throws -> [ExplicitLink] {
        var links: [ExplicitLink] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                links.append(ExplicitLink(
                    sourceNoteID: NoteID(stringColumn(0, in: statement)),
                    targetNoteID: NoteID(stringColumn(1, in: statement)),
                    snippet: stringColumn(2, in: statement)
                ))
            } else if result == SQLITE_DONE {
                return links
            } else {
                throw SQLiteGraphStoreError.stepFailed(sqliteMessage())
            }
        }
    }

    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try work()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteGraphStoreError.executionFailed(sqliteMessage())
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteGraphStoreError.prepareFailed(sqliteMessage())
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, sqliteGraphStoreTransient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteGraphStoreError.bindFailed(sqliteMessage())
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteGraphStoreError.stepFailed(sqliteMessage())
        }
    }

    private func rowCount(in table: String) throws -> Int {
        let statement = try prepare("SELECT COUNT(*) FROM \(table)")
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            throw SQLiteGraphStoreError.stepFailed(sqliteMessage())
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func stringColumn(_ index: Int32, in statement: OpaquePointer?) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    private func sqliteMessage() -> String {
        String(cString: sqlite3_errmsg(database))
    }
}

private let sqliteGraphStoreTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteGraphStoreError: Error, Equatable {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
}
