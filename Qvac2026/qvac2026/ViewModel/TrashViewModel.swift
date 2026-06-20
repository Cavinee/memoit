//
//  TrashViewModel.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import Foundation
import Combine

@MainActor
final class TrashViewModel: ObservableObject {

    @Published var trashed:           [Note] = []
    @Published var showEmptyConfirm:  Bool   = false
    @Published var deleteTarget:      Note?

    private var notes: KnowledgeRuntimeService { KnowledgeRuntimeService.shared }

    func load() {
        trashed = notes.trashedNotes()
    }

    func emptyAll() {
        notes.emptyTrash()
        trashed = []
    }

    func permanentlyDelete(_ note: Note) {
        notes.permanentlyDelete(id: note.id)
        trashed = notes.trashedNotes()
    }

    func restore(_ note: Note) {
        notes.restoreFromTrash(id: note.id)
        trashed = notes.trashedNotes()
    }

    func subtitleText(for note: Note) -> String {
        guard let deletedAt = note.deletedAt else { return "" }
        let days = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        let deletedLabel = days == 0 ? "today" : days == 1 ? "1 day ago" : "\(days) days ago"
        return "Deleted \(deletedLabel)"
    }
}
