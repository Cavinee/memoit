//
//  ChatHistoryViewModel.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import Foundation
import Combine
import QVACRuntime

@MainActor
final class ChatHistoryViewModel: ObservableObject {

    @Published var entries: [PresentationAISessionHistoryEntry] = []
    @Published var deletionErrorMessage: String?

    private let loadHistory: @MainActor () -> [PresentationAISessionHistoryEntry]
    private let deleteHistoryEntry: @MainActor (AISessionHistoryEntryID) throws -> Void
    private var deletionPresentationState = ChatHistoryDeletionPresentationState()

    init(
        loadHistory: (@MainActor () -> [PresentationAISessionHistoryEntry])? = nil,
        deleteHistoryEntry: (@MainActor (AISessionHistoryEntryID) throws -> Void)? = nil
    ) {
        self.loadHistory = loadHistory ?? {
            KnowledgeRuntimeService.shared.aiSessionHistory()
        }
        self.deleteHistoryEntry = deleteHistoryEntry ?? {
            try KnowledgeRuntimeService.shared.deleteAISessionHistoryEntry(id: $0)
        }
    }

    func load() {
        entries = loadHistory()
    }

    func delete(entryID: AISessionHistoryEntryID) {
        do {
            try deleteHistoryEntry(entryID)
            deletionPresentationState.didDeleteSuccessfully()
            deletionErrorMessage = deletionPresentationState.errorMessage
            load()
        } catch {
            deletionPresentationState.didFailToDelete()
            deletionErrorMessage = deletionPresentationState.errorMessage
        }
    }
}
