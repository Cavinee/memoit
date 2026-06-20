public enum RuntimeError: Error, Equatable, Sendable {
    case noteNotFound(NoteID)
    case noteNotInTrash(NoteID)
    case deletionConfirmationRequired(NoteID)
    case runtimeCommandNotAllowedForAI
    case relationshipScanRequiresActiveNote(NoteID)
    case relationshipScanRequiresNonPlaceholderNote(NoteID)
    case localModelProfileNotFound(LocalModelProfileID)
    case localModelProfileNotRemovable(LocalModelProfileID)
    case aiUnavailable(AIUnavailableState)
    case indexNotFresh(DerivedIndex)
    case noRetrievedContext(AnswerMode)
    case aiSessionHistoryEntryNotFound(AISessionHistoryEntryID)
    case aiOperationNotFound(AIOperationID)
    case aiWriteDestinationRequired
    case draftChangeNotFound(DraftChangeID)
    case aiGeneratedWriteCountMismatch
    case aiOperationCommitFailed
}
