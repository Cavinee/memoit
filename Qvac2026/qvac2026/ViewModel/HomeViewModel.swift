//
//  HomeViewModel.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import Foundation
import Combine

struct NoteGroup {
    let title: String
    let notes: [Note]
}

/// The payload for the "Find Related Notes" sheet: the title of the note the user asked
/// about and the notes the on-device embedding index ranked as most related to it.
struct RelatedNotesResult: Identifiable {
    let id = UUID()
    let sourceTitle: String
    let related: [Note]
}

@MainActor
final class HomeViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var allNotes:   [Note] = []
    @Published var relatedResult: RelatedNotesResult?

    private var notes: KnowledgeRuntimeService { KnowledgeRuntimeService.shared }

    func refresh() {
        allNotes = notes.activeNotes()
    }

    var groupedNotes: [NoteGroup] {
        guard !searchText.isEmpty else {
            let home = notes.homeNoteList()
            let pinned = home.pinnedNotes.isEmpty ? [] : [
                NoteGroup(title: "PINNED", notes: home.pinnedNotes)
            ]
            return pinned + home.groups.map {
                NoteGroup(title: $0.title, notes: $0.notes)
            }
        }

        let source = notes.search(query: searchText)

        let pinned    = source.filter { $0.pinned }
        let unpinned  = source.filter { !$0.pinned }.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }

        let now = Date()
        let today     = unpinned.filter { now.timeIntervalSince($0.updatedAt) < 86_400 }
        let yesterday = unpinned.filter {
            let age = now.timeIntervalSince($0.updatedAt)
            return age >= 86_400 && age < 172_800
        }
        let older     = unpinned.filter { now.timeIntervalSince($0.updatedAt) >= 172_800 }

        return [
            NoteGroup(title: "PINNED",      notes: pinned),
            NoteGroup(title: "TODAY",       notes: today),
            NoteGroup(title: "YESTERDAY",   notes: yesterday),
            NoteGroup(title: "A WEEK AGO",  notes: older)
        ]
        .filter { !$0.notes.isEmpty }
    }

    // MARK: - Actions

    func togglePin(_ note: Note) {
        notes.setPinned(id: note.id, pinned: !note.pinned)
        refresh()
    }

    func delete(_ note: Note) {
        notes.moveToTrash(id: note.id)
        refresh()
    }

    /// Finds notes related to `note` via on-device embedding similarity and presents
    /// them in the related-notes sheet. Pure in-memory cosine ranking — no generation
    /// worklet, so it stays off the `.qvac` model path and returns promptly.
    func findRelated(_ note: Note) {
        relatedResult = RelatedNotesResult(
            sourceTitle: note.title,
            related: notes.relatedNotes(to: note.id)
        )
    }
}
