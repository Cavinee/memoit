public struct SavedAIResponseID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct AIOperationID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct DraftChangeID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct AISessionID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public enum AIEditingMode: Equatable, Sendable {
    case draftChange
    case directEdit
}

public struct AIEditingPermission: Equatable, Sendable {
    public let sessionID: AISessionID
    public let mode: AIEditingMode

    public init(sessionID: AISessionID, mode: AIEditingMode) {
        self.sessionID = sessionID
        self.mode = mode
    }
}

public enum AIWriteDestination: Equatable, Sendable {
    case existingNote(NoteID)
    case newNote(title: String)
}

public struct DraftChange: Equatable, Sendable {
    public let id: DraftChangeID
    public let noteID: NoteID
    public let body: String
    public let localModelProfileID: LocalModelProfileID?

    public init(id: DraftChangeID, noteID: NoteID, body: String, localModelProfileID: LocalModelProfileID? = nil) {
        self.id = id
        self.noteID = noteID
        self.body = body
        self.localModelProfileID = localModelProfileID
    }
}

public struct AIChange: Equatable, Sendable {
    public let noteID: NoteID
    public let previousNote: Note?
    public let newNote: Note?

    public init(noteID: NoteID, previousNote: Note?, newNote: Note?) {
        self.noteID = noteID
        self.previousNote = previousNote
        self.newNote = newNote
    }
}

public struct AIOperation: Equatable, Sendable {
    public let id: AIOperationID
    public let localModelProfileID: LocalModelProfileID?
    public let changes: [AIChange]
    public let createdPlaceholderNoteIDs: [NoteID]
    public let isReversed: Bool

    public init(id: AIOperationID, createdNoteID: NoteID, isReversed: Bool) {
        self.id = id
        self.localModelProfileID = nil
        self.changes = [AIChange(noteID: createdNoteID, previousNote: nil, newNote: nil)]
        self.createdPlaceholderNoteIDs = []
        self.isReversed = isReversed
    }

    public init(id: AIOperationID, localModelProfileID: LocalModelProfileID?, changes: [AIChange], createdPlaceholderNoteIDs: [NoteID] = [], isReversed: Bool) {
        self.id = id
        self.localModelProfileID = localModelProfileID
        self.changes = changes
        self.createdPlaceholderNoteIDs = createdPlaceholderNoteIDs
        self.isReversed = isReversed
    }

    public var createdNoteID: NoteID {
        changes[0].noteID
    }

    public var isReversible: Bool {
        !isReversed
    }
}

public enum AIWriteWorkflowResult: Equatable, Sendable {
    case draftChange(DraftChange)
    case directEdit(AIOperation)
    case canceled
}

public enum SavedAIResponseDestination: Equatable, Sendable {
    case newNote(title: String)
    case draftChange(noteID: NoteID)
}

public enum SavedAIResponseResolvedDestination: Equatable, Sendable {
    case note(Note)
    case draftChange(DraftChange)
}

public struct SavedAIResponse: Equatable, Sendable {
    public let id: SavedAIResponseID
    public let response: String
    public let destination: SavedAIResponseResolvedDestination
    public let aiOperation: AIOperation?

    public init(id: SavedAIResponseID, response: String, destination: SavedAIResponseResolvedDestination, aiOperation: AIOperation?) {
        self.id = id
        self.response = response
        self.destination = destination
        self.aiOperation = aiOperation
    }
}

final class SavedAIResponseStore {
    private var draftChanges: [DraftChange] = []
    private var nextResponseNumber = 1
    private var nextDraftChangeNumber = 1

    func record(response: String, destination: SavedAIResponseResolvedDestination, aiOperation: AIOperation?) -> SavedAIResponse {
        let saved = SavedAIResponse(
            id: .init("saved-ai-response-\(nextResponseNumber)"),
            response: response,
            destination: destination,
            aiOperation: aiOperation
        )
        nextResponseNumber += 1
        return saved
    }

    func createDraftChange(noteID: NoteID, body: String, localModelProfileID: LocalModelProfileID? = nil) -> DraftChange {
        let draftChange = DraftChange(
            id: .init("draft-change-\(nextDraftChangeNumber)"),
            noteID: noteID,
            body: body,
            localModelProfileID: localModelProfileID
        )
        nextDraftChangeNumber += 1
        draftChanges.append(draftChange)
        return draftChange
    }

    func draftChange(withID draftChangeID: DraftChangeID) throws -> DraftChange {
        guard let draftChange = draftChanges.first(where: { $0.id == draftChangeID }) else {
            throw RuntimeError.draftChangeNotFound(draftChangeID)
        }

        return draftChange
    }

    func deleteDraftChange(draftChangeID: DraftChangeID) {
        draftChanges.removeAll { $0.id == draftChangeID }
    }
}

final class AIOperationStore {
    private var operationsByID: [AIOperationID: AIOperation] = [:]
    private var operationOrder: [AIOperationID] = []
    private var pendingOperationsByID: [AIOperationID: AIOperation] = [:]
    private var nextOperationNumber = 1
    private var shouldFailNextCommit = false

    func recordCreatedNote(noteID: NoteID, localModelProfileID: LocalModelProfileID? = nil, newNote: Note? = nil, createdPlaceholderNoteIDs: [NoteID] = []) -> AIOperation {
        let operation = AIOperation(
            id: .init("ai-operation-\(nextOperationNumber)"),
            localModelProfileID: localModelProfileID,
            changes: [AIChange(noteID: noteID, previousNote: nil, newNote: newNote)],
            createdPlaceholderNoteIDs: createdPlaceholderNoteIDs,
            isReversed: false
        )
        nextOperationNumber += 1
        operationsByID[operation.id] = operation
        operationOrder.append(operation.id)
        return operation
    }

    func record(localModelProfileID: LocalModelProfileID?, changes: [AIChange], createdPlaceholderNoteIDs: [NoteID] = []) throws -> AIOperation {
        if shouldFailNextCommit {
            shouldFailNextCommit = false
            throw RuntimeError.aiOperationCommitFailed
        }

        let operation = AIOperation(
            id: .init("ai-operation-\(nextOperationNumber)"),
            localModelProfileID: localModelProfileID,
            changes: changes,
            createdPlaceholderNoteIDs: createdPlaceholderNoteIDs,
            isReversed: false
        )
        nextOperationNumber += 1
        operationsByID[operation.id] = operation
        operationOrder.append(operation.id)
        return operation
    }

    func replace(operationID: AIOperationID, changes: [AIChange], createdPlaceholderNoteIDs: [NoteID]) throws -> AIOperation {
        let operation = try operation(withID: operationID)
        let replacement = AIOperation(
            id: operation.id,
            localModelProfileID: operation.localModelProfileID,
            changes: changes,
            createdPlaceholderNoteIDs: createdPlaceholderNoteIDs,
            isReversed: operation.isReversed
        )
        operationsByID[operationID] = replacement
        return replacement
    }

    func failNextCommit() {
        shouldFailNextCommit = true
    }

    func list() -> [AIOperation] {
        operationOrder.compactMap { operationsByID[$0] }
    }

    func beginIncomplete(localModelProfileID: LocalModelProfileID?, changes: [AIChange]) -> AIOperationID {
        let operation = AIOperation(
            id: .init("ai-operation-\(nextOperationNumber)"),
            localModelProfileID: localModelProfileID,
            changes: changes,
            createdPlaceholderNoteIDs: [],
            isReversed: false
        )
        nextOperationNumber += 1
        pendingOperationsByID[operation.id] = operation
        return operation.id
    }

    func discardIncompleteOperations() {
        pendingOperationsByID.removeAll()
    }

    func operation(withID operationID: AIOperationID) throws -> AIOperation {
        guard let operation = operationsByID[operationID] else {
            throw RuntimeError.aiOperationNotFound(operationID)
        }

        return operation
    }

    func markReversed(operationID: AIOperationID) throws -> AIOperation {
        let operation = try operation(withID: operationID)
        let reversed = AIOperation(
            id: operation.id,
            localModelProfileID: operation.localModelProfileID,
            changes: operation.changes,
            createdPlaceholderNoteIDs: operation.createdPlaceholderNoteIDs,
            isReversed: true
        )
        operationsByID[operationID] = reversed
        return reversed
    }
}
