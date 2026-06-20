//
//  Note.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation

enum NoteType: String, Equatable {
    case text  = "text"
    case audio = "audio"
    case file  = "file"
}

struct Note: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var preview: String
    var content: String
    var contentRTF: Data? = nil
    var type: NoteType
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var pinned: Bool = false

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: .now)
    }
}

#if DEBUG
extension Note {
    static var samples: [Note] {
        let calendar = Calendar.current
        let now = Date()

        func date(hoursAgo hours: Int, daysAgo days: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: -days, to: now)!
            return calendar.date(byAdding: .hour, value: -hours, to: base)!
        }

        return [
            Note(title: "Coffee shop recommendation in G...",
                 preview: "Try the new café near the office. Sandy ...",
                 content: "Try the new café near the office. Sandy recommended it.",
                 type: .text,
                 createdAt: date(hoursAgo: 1),
                 updatedAt: date(hoursAgo: 1)),

            Note(title: "Final test to do list",
                 preview: "Items to complete before the demo day ...",
                 content: "Items to complete before the demo day.",
                 type: .file,
                 createdAt: date(hoursAgo: 2),
                 updatedAt: date(hoursAgo: 2)),

            Note(title: "Interview with user",
                 preview: "Key insights from the research session ...",
                 content: "Key insights from the research session.",
                 type: .audio,
                 createdAt: date(hoursAgo: 2, daysAgo: 100),
                 updatedAt: date(hoursAgo: 2, daysAgo: 100)),

            Note(title: "Coffee shop recommendation in G...",
                 preview: "Try the new café near the office. Sandy ...",
                 content: "Try the new café near the office. Sandy recommended it.",
                 type: .text,
                 createdAt: date(hoursAgo: 4, daysAgo: 1),
                 updatedAt: date(hoursAgo: 4, daysAgo: 1)),

            Note(title: "Coffee shop recommendation in G...",
                 preview: "Try the new café near the office. Sandy ...",
                 content: "Try the new café near the office. Sandy recommended it.",
                 type: .text,
                 createdAt: date(hoursAgo: 6, daysAgo: 1),
                 updatedAt: date(hoursAgo: 6, daysAgo: 1)),

            Note(title: "Weekly project review",
                 preview: "QVAC hackathon progress and next steps ...",
                 content: "QVAC hackathon progress and next steps.",
                 type: .file,
                 createdAt: date(hoursAgo: 0, daysAgo: 4),
                 updatedAt: date(hoursAgo: 0, daysAgo: 4))
        ]
    }
}
#endif
