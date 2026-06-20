final class UserSearchIndex {
    private var records: [UserSearchIndexRecord] = []
    private(set) var freshness: IndexFreshness = .fresh

    func markDirty() {
        freshness = .dirty
    }

    func rebuild(from notes: [Note]) {
        records = notes.map { note in
            UserSearchIndexRecord(noteID: note.id, searchableText: "\(note.title)\n\(note.body)".lowercased())
        }
        freshness = .fresh
    }

    func search(_ query: String) -> [NoteID] {
        let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace })
        guard !terms.isEmpty else {
            return []
        }

        return records.compactMap { record in
            terms.allSatisfy { record.searchableText.contains($0) } ? record.noteID : nil
        }
    }
}

private struct UserSearchIndexRecord {
    let noteID: NoteID
    let searchableText: String
}
