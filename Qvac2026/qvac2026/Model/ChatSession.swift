//
//  ChatSession.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation

struct ChatSession: Identifiable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date
    var updatedAt: Date
}
