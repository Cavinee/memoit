//
//  DatabaseService.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

class DatabaseService {

    static let shared = DatabaseService()

    let connection: Connection

    lazy var notes       = NoteRepository(db: connection)
    lazy var attachments = AttachmentRepository(db: connection)
    lazy var chats       = ChatRepository(db: connection)
    lazy var settings    = SettingsRepository(db: connection)

    private init() {
        let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("qvac.sqlite3")
            .path

        connection = try! Connection(path)
        try! connection.execute("PRAGMA foreign_keys = ON")
        try! connection.execute("PRAGMA journal_mode = DELETE")
        SchemaMigrator.run(on: connection)
    }
}
