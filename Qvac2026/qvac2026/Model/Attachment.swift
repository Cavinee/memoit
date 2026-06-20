//
//  Attachment.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation

enum AttachmentType: String, Codable {
    case audio  = "audio"
    case image  = "image"
    case file   = "file"
    case camera = "camera"
}

struct Attachment: Identifiable {
    var id: UUID = UUID()
    var noteId: UUID
    var type: AttachmentType
    var filename: String
    var filePath: String
    var mimeType: String?
    var sizeBytes: Int64
    var durationMs: Int?
    var transcript: String?
    var createdAt: Date
}
