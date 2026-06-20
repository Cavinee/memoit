//
//  SchemaMigrator.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

enum SchemaMigrator {
    static let currentSchemaVersion: Int64 = 3

    static func run(on db: Connection) {
        do {
            let version = (try? db.scalar("PRAGMA user_version") as? Int64) ?? 0
            if version < 1 { try migrateToV1(db) }
            if version < 2 { try migrateToV2(db) }
            if version < 3 { try migrateToV3(db) }
        } catch {
            print("SchemaMigrator error: \(error)")
        }
    }

    private static func migrateToV1(_ db: Connection) throws {
        // notes
        try db.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id          TEXT PRIMARY KEY NOT NULL,
                title       TEXT NOT NULL,
                preview     TEXT NOT NULL,
                content     TEXT NOT NULL DEFAULT '',
                type        TEXT NOT NULL,
                created_at  REAL NOT NULL,
                updated_at  REAL NOT NULL,
                deleted_at  REAL
            )
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at DESC)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON notes(deleted_at)")

        // attachments
        try db.execute("""
            CREATE TABLE IF NOT EXISTS attachments (
                id           TEXT PRIMARY KEY NOT NULL,
                note_id      TEXT NOT NULL,
                type         TEXT NOT NULL,
                filename     TEXT NOT NULL,
                file_path    TEXT NOT NULL,
                mime_type    TEXT,
                size_bytes   INTEGER NOT NULL DEFAULT 0,
                duration_ms  INTEGER,
                transcript   TEXT,
                created_at   REAL NOT NULL,
                FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
            )
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON attachments(note_id)")

        // chat_sessions
        try db.execute("""
            CREATE TABLE IF NOT EXISTS chat_sessions (
                id          TEXT PRIMARY KEY NOT NULL,
                title       TEXT NOT NULL,
                created_at  REAL NOT NULL,
                updated_at  REAL NOT NULL
            )
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_chat_sessions_updated_at ON chat_sessions(updated_at DESC)")

        // chat_messages
        try db.execute("""
            CREATE TABLE IF NOT EXISTS chat_messages (
                id          TEXT PRIMARY KEY NOT NULL,
                session_id  TEXT NOT NULL,
                role        TEXT NOT NULL,
                content     TEXT NOT NULL,
                created_at  REAL NOT NULL,
                FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
            )
        """)
        try db.execute("CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, created_at ASC)")

        // settings
        try db.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key         TEXT PRIMARY KEY NOT NULL,
                value       TEXT NOT NULL,
                updated_at  REAL NOT NULL
            )
        """)

        try db.execute("PRAGMA user_version = 1")
    }

    private static func migrateToV2(_ db: Connection) throws {
        try db.execute("ALTER TABLE notes ADD COLUMN content_rtf BLOB")
        try db.execute("PRAGMA user_version = 2")
    }

    private static func migrateToV3(_ db: Connection) throws {
        try db.execute("ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
        try db.execute("PRAGMA user_version = 3")
    }
}
