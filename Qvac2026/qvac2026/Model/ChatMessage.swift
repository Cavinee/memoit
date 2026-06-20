//
//  ChatMessage.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation

enum ChatRole: String, Codable {
    case user      = "user"
    case assistant = "assistant"
    case system    = "system"
}

struct ChatMessage: Identifiable {
    var id: UUID = UUID()
    var sessionId: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date
}
