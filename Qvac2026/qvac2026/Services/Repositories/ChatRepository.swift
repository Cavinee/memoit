//
//  ChatRepository.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

final class ChatRepository {
    private let db: Connection

    private let sessionsTable     = Table("chat_sessions")
    private let colSessionId      = Expression<String>("id")
    private let colSessionTitle   = Expression<String>("title")
    private let colSessionCreated = Expression<Double>("created_at")
    private let colSessionUpdated = Expression<Double>("updated_at")

    private let messagesTable   = Table("chat_messages")
    private let colMsgId        = Expression<String>("id")
    private let colMsgSessionId = Expression<String>("session_id")
    private let colMsgRole      = Expression<String>("role")
    private let colMsgContent   = Expression<String>("content")
    private let colMsgCreated   = Expression<Double>("created_at")

    init(db: Connection) {
        self.db = db
    }

    // MARK: - Sessions

    func fetchSessions() -> [ChatSession] {
        guard let rows = try? db.prepare(
            sessionsTable.order(colSessionUpdated.desc)
        ) else { return [] }
        return rows.map { rowToSession($0) }
    }

    func fetchSession(id: UUID) -> ChatSession? {
        guard let rows = try? db.prepare(
            sessionsTable.filter(colSessionId == id.uuidString)
        ) else { return nil }
        return rows.map { rowToSession($0) }.first
    }

    func insertSession(_ session: ChatSession) {
        do {
            try db.run(sessionsTable.insert(
                colSessionId      <- session.id.uuidString,
                colSessionTitle   <- session.title,
                colSessionCreated <- session.createdAt.timeIntervalSince1970,
                colSessionUpdated <- session.updatedAt.timeIntervalSince1970
            ))
        } catch {
            print("ChatRepository insertSession error: \(error)")
        }
    }

    func renameSession(id: UUID, title: String) {
        let target = sessionsTable.filter(colSessionId == id.uuidString)
        do {
            try db.run(target.update(
                colSessionTitle   <- title,
                colSessionUpdated <- Date().timeIntervalSince1970
            ))
        } catch {
            print("ChatRepository renameSession error: \(error)")
        }
    }

    func deleteSession(id: UUID) {
        let target = sessionsTable.filter(colSessionId == id.uuidString)
        do {
            try db.run(target.delete())
        } catch {
            print("ChatRepository deleteSession error: \(error)")
        }
    }

    // MARK: - Messages

    func fetchMessages(sessionId: UUID) -> [ChatMessage] {
        guard let rows = try? db.prepare(
            messagesTable
                .filter(colMsgSessionId == sessionId.uuidString)
                .order(colMsgCreated.asc)
        ) else { return [] }
        return rows.map { rowToMessage($0) }
    }

    func appendMessage(_ message: ChatMessage) {
        do {
            try db.run(messagesTable.insert(
                colMsgId        <- message.id.uuidString,
                colMsgSessionId <- message.sessionId.uuidString,
                colMsgRole      <- message.role.rawValue,
                colMsgContent   <- message.content,
                colMsgCreated   <- message.createdAt.timeIntervalSince1970
            ))
            let target = sessionsTable.filter(colSessionId == message.sessionId.uuidString)
            try db.run(target.update(colSessionUpdated <- Date().timeIntervalSince1970))
        } catch {
            print("ChatRepository appendMessage error: \(error)")
        }
    }

    func deleteMessage(id: UUID) {
        let target = messagesTable.filter(colMsgId == id.uuidString)
        do {
            try db.run(target.delete())
        } catch {
            print("ChatRepository deleteMessage error: \(error)")
        }
    }

    // MARK: - Private

    private func rowToSession(_ row: Row) -> ChatSession {
        ChatSession(
            id:        UUID(uuidString: row[colSessionId]) ?? UUID(),
            title:     row[colSessionTitle],
            createdAt: Date(timeIntervalSince1970: row[colSessionCreated]),
            updatedAt: Date(timeIntervalSince1970: row[colSessionUpdated])
        )
    }

    private func rowToMessage(_ row: Row) -> ChatMessage {
        ChatMessage(
            id:        UUID(uuidString: row[colMsgId]) ?? UUID(),
            sessionId: UUID(uuidString: row[colMsgSessionId]) ?? UUID(),
            role:      ChatRole(rawValue: row[colMsgRole]) ?? .user,
            content:   row[colMsgContent],
            createdAt: Date(timeIntervalSince1970: row[colMsgCreated])
        )
    }
}
