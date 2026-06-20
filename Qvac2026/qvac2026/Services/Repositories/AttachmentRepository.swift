//
//  AttachmentRepository.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

final class AttachmentRepository {
    private let db: Connection

    private let table         = Table("attachments")
    private let colId         = Expression<String>("id")
    private let colNoteId     = Expression<String>("note_id")
    private let colType       = Expression<String>("type")
    private let colFilename   = Expression<String>("filename")
    private let colFilePath   = Expression<String>("file_path")
    private let colMimeType   = Expression<String?>("mime_type")
    private let colSizeBytes  = Expression<Int64>("size_bytes")
    private let colDurationMs = Expression<Int64?>("duration_ms")
    private let colTranscript = Expression<String?>("transcript")
    private let colCreatedAt  = Expression<Double>("created_at")

    init(db: Connection) {
        self.db = db
    }

    func fetch(forNoteId noteId: UUID) -> [Attachment] {
        guard let rows = try? db.prepare(
            table.filter(colNoteId == noteId.uuidString).order(colCreatedAt.asc)
        ) else { return [] }
        return rows.map { rowToAttachment($0) }
    }

    func fetch(id: UUID) -> Attachment? {
        guard let rows = try? db.prepare(
            table.filter(colId == id.uuidString)
        ) else { return nil }
        return rows.map { rowToAttachment($0) }.first
    }

    func insert(_ attachment: Attachment) {
        do {
            try db.run(table.insert(
                colId         <- attachment.id.uuidString,
                colNoteId     <- attachment.noteId.uuidString,
                colType       <- attachment.type.rawValue,
                colFilename   <- attachment.filename,
                colFilePath   <- attachment.filePath,
                colMimeType   <- attachment.mimeType,
                colSizeBytes  <- attachment.sizeBytes,
                colDurationMs <- attachment.durationMs.map { Int64($0) },
                colTranscript <- attachment.transcript,
                colCreatedAt  <- attachment.createdAt.timeIntervalSince1970
            ))
        } catch {
            print("AttachmentRepository insert error: \(error)")
        }
    }

    func rename(id: UUID, filename: String) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(colFilename <- filename))
        } catch {
            print("AttachmentRepository rename error: \(error)")
        }
    }

    func updateTranscript(id: UUID, transcript: String) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.update(colTranscript <- transcript))
        } catch {
            print("AttachmentRepository updateTranscript error: \(error)")
        }
    }

    func delete(id: UUID) {
        let target = table.filter(colId == id.uuidString)
        do {
            try db.run(target.delete())
        } catch {
            print("AttachmentRepository delete error: \(error)")
        }
    }

    func deleteAll(forNoteId noteId: UUID) {
        let target = table.filter(colNoteId == noteId.uuidString)
        do {
            try db.run(target.delete())
        } catch {
            print("AttachmentRepository deleteAll error: \(error)")
        }
    }

    private func rowToAttachment(_ row: Row) -> Attachment {
        Attachment(
            id:         UUID(uuidString: row[colId]) ?? UUID(),
            noteId:     UUID(uuidString: row[colNoteId]) ?? UUID(),
            type:       AttachmentType(rawValue: row[colType]) ?? .file,
            filename:   row[colFilename],
            filePath:   row[colFilePath],
            mimeType:   row[colMimeType],
            sizeBytes:  row[colSizeBytes],
            durationMs: row[colDurationMs].map { Int($0) },
            transcript: row[colTranscript],
            createdAt:  Date(timeIntervalSince1970: row[colCreatedAt])
        )
    }
}
