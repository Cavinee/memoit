//
//  NoteRepository.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

final class NoteRepository {
    private let db: Connection

    private let table        = Table("notes")
    private let colId        = Expression<String>("id")
    private let colTitle     = Expression<String>("title")
    private let colPreview   = Expression<String>("preview")
    private let colContent   = Expression<String>("content")
    private let colType      = Expression<String>("type")
    private let colCreatedAt = Expression<Double>("created_at")
    private let colUpdatedAt = Expression<Double>("updated_at")
    private let colDeletedAt   = Expression<Double?>("deleted_at")
    private let colContentRTF  = Expression<Data?>("content_rtf")
    private let colPinned      = Expression<Bool>("pinned")

    init(db: Connection) {
        self.db = db
    }

    // MARK: - Reads

    func fetchActive() -> [Note] {
        guard let rows = try? db.prepare(
            table.filter(colDeletedAt == nil).order(colPinned.desc, colUpdatedAt.desc)
        ) else { return [] }
        return rows.map { rowToNote($0) }
    }

    func fetchTrashed() -> [Note] {
        guard let rows = try? db.prepare(
            table.filter(colDeletedAt != nil).order(colDeletedAt.desc)
        ) else { return [] }
        return rows.map { rowToNote($0) }
    }

    func fetch(id: UUID) -> Note? {
        guard let rows = try? db.prepare(
            table.filter(colId == id.uuidString)
        ) else { return nil }
        return rows.map { rowToNote($0) }.first
    }

    func search(query: String) -> [Note] {
        let pattern = "%\(query)%"
        guard let rows = try? db.prepare(
            table
                .filter(colDeletedAt == nil)
                .filter(colTitle.like(pattern) || colContent.like(pattern))
                .order(colUpdatedAt.desc)
        ) else { return [] }
        return rows.map { rowToNote($0) }
    }

    func fetchRecent(limit: Int) -> [Note] {
        guard let rows = try? db.prepare(
            table.filter(colDeletedAt == nil).order(colUpdatedAt.desc).limit(limit)
        ) else { return [] }
        return rows.map { rowToNote($0) }
    }

    // MARK: - Writes

    func insert(_ note: Note) {
        do {
            try db.run(table.insert(
                colId         <- note.id.uuidString,
                colTitle      <- note.title,
                colPreview    <- note.preview,
                colContent    <- note.content,
                colContentRTF <- note.contentRTF,
                colType       <- note.type.rawValue,
                colCreatedAt  <- note.createdAt.timeIntervalSince1970,
                colUpdatedAt  <- note.updatedAt.timeIntervalSince1970,
                colDeletedAt  <- note.deletedAt?.timeIntervalSince1970,
                colPinned     <- note.pinned
            ))
        } catch {
            print("NoteRepository insert error: \(error)")
        }
    }

    func update(_ note: Note) {
        let target = table.filter(colId == note.id.uuidString)
        do {
            try db.run(target.update(
                colTitle      <- note.title,
                colPreview    <- note.preview,
                colContent    <- note.content,
                colContentRTF <- note.contentRTF,
                colType       <- note.type.rawValue,
                colUpdatedAt  <- note.updatedAt.timeIntervalSince1970,
                colDeletedAt  <- note.deletedAt?.timeIntervalSince1970,
                colPinned     <- note.pinned
            ))
        } catch {
            print("NoteRepository update error: \(error)")
        }
    }

    func rename(id: UUID, title: String) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(
                colTitle     <- title,
                colUpdatedAt <- Date().timeIntervalSince1970
            ))
        } catch {
            print("NoteRepository rename error: \(error)")
        }
    }

    func updateContent(id: UUID, content: String, contentRTF: Data?, preview: String) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(
                colContent    <- content,
                colContentRTF <- contentRTF,
                colPreview    <- preview,
                colUpdatedAt  <- Date().timeIntervalSince1970
            ))
        } catch {
            print("NoteRepository updateContent error: \(error)")
        }
    }

    // MARK: - Trash

    func moveToTrash(id: UUID) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(colDeletedAt <- Date().timeIntervalSince1970))
        } catch {
            print("NoteRepository moveToTrash error: \(error)")
        }
    }

    func restoreFromTrash(id: UUID) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(colDeletedAt <- nil))
        } catch {
            print("NoteRepository restoreFromTrash error: \(error)")
        }
    }

    func permanentlyDelete(id: UUID) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.delete())
        } catch {
            print("NoteRepository permanentlyDelete error: \(error)")
        }
    }

    func emptyTrash() {
        let target = table.filter(colDeletedAt != nil)
        do {
            try db.run(target.delete())
        } catch {
            print("NoteRepository emptyTrash error: \(error)")
        }
    }

    func purgeExpiredTrash(olderThanDays days: Int = 30) {
        let cutoff = Date().timeIntervalSince1970 - Double(days) * 86_400
        let target = table.filter(colDeletedAt != nil && colDeletedAt < cutoff)
        do {
            try db.run(target.delete())
        } catch {
            print("NoteRepository purgeExpiredTrash error: \(error)")
        }
    }

    // MARK: - Pin

    func setPinned(id: UUID, pinned: Bool) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(colPinned <- pinned))
        } catch {
            print("NoteRepository setPinned error: \(error)")
        }
    }

    // MARK: - Private

    private func rowToNote(_ row: Row) -> Note {
        Note(
            id:         UUID(uuidString: row[colId]) ?? UUID(),
            title:      row[colTitle],
            preview:    row[colPreview],
            content:    row[colContent],
            contentRTF: row[colContentRTF],
            type:       NoteType(rawValue: row[colType]) ?? .text,
            createdAt:  Date(timeIntervalSince1970: row[colCreatedAt]),
            updatedAt:  Date(timeIntervalSince1970: row[colUpdatedAt]),
            deletedAt:  row[colDeletedAt].map { Date(timeIntervalSince1970: $0) },
            pinned:     row[colPinned]
        )
    }
}
