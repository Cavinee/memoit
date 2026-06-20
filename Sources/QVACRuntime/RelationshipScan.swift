public struct SourceCitation: Equatable, Sendable {
    public let noteID: NoteID
    public let noteFragmentID: String

    public init(noteID: NoteID, noteFragmentID: String) {
        self.noteID = noteID
        self.noteFragmentID = noteFragmentID
    }
}

public struct SuggestedRelationship: Equatable, Sendable {
    public let sourceNoteID: NoteID
    public let targetNoteID: NoteID
    public let explanation: String
    public let citations: [SourceCitation]

    public init(sourceNoteID: NoteID, targetNoteID: NoteID, explanation: String, citations: [SourceCitation]) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.explanation = explanation
        self.citations = citations
    }
}

public protocol AIRuntimeAdapter {
    func modelAvailability() throws -> AIRuntimeModelAvailability
    func suggestedRelationships(for sourceNote: Note, in corpus: [Note]) throws -> [SuggestedRelationship]
    func answer(prompt: String, mode: AnswerMode, context: [Note]) throws -> String
    func generatedNoteBodies(prompt: String, destinationCount: Int) throws -> AIWriteAdapterResult
    func summary(for notes: [Note], progress: (AIProgressState) -> Void) throws -> String
}

public struct AIRuntimeModelAvailability: Equatable, Sendable {
    public let isAIReady: Bool
    public let inventory: ModelInventory

    public init(isAIReady: Bool, inventory: ModelInventory) {
        self.isAIReady = isAIReady
        self.inventory = inventory
    }
}

public enum AIWriteAdapterResult: Equatable, Sendable {
    case completed([String])
    case canceled
}

public struct FakeAIRuntimeAdapter: AIRuntimeAdapter {
    private let suggestions: [SuggestedRelationship]
    private let generatedNoteBodiesResult: AIWriteAdapterResult
    private let summaryResult: String?
    private let onSummaryProgress: ((AIProgressState) throws -> Void)?
    private let modelAvailabilityScript: FakeAIRuntimeModelAvailabilityScript

    public init(suggestions: [SuggestedRelationship] = [], generatedNoteBodies: AIWriteAdapterResult = .completed([]), summary: String? = nil, onSummaryProgress: ((AIProgressState) throws -> Void)? = nil, modelAvailability: AIRuntimeModelAvailability = .init(isAIReady: false, inventory: ModelInventory(downloadedProfiles: [], defaultProfileID: nil))) {
        self.suggestions = suggestions
        self.generatedNoteBodiesResult = generatedNoteBodies
        self.summaryResult = summary
        self.onSummaryProgress = onSummaryProgress
        self.modelAvailabilityScript = FakeAIRuntimeModelAvailabilityScript([modelAvailability])
    }

    public init(suggestions: [SuggestedRelationship] = [], generatedNoteBodies: AIWriteAdapterResult = .completed([]), summary: String? = nil, onSummaryProgress: ((AIProgressState) throws -> Void)? = nil, modelAvailabilityResponses: [AIRuntimeModelAvailability]) {
        self.suggestions = suggestions
        self.generatedNoteBodiesResult = generatedNoteBodies
        self.summaryResult = summary
        self.onSummaryProgress = onSummaryProgress
        self.modelAvailabilityScript = FakeAIRuntimeModelAvailabilityScript(modelAvailabilityResponses)
    }

    public func modelAvailability() throws -> AIRuntimeModelAvailability {
        modelAvailabilityScript.next()
    }

    public func suggestedRelationships(for sourceNote: Note, in corpus: [Note]) throws -> [SuggestedRelationship] {
        suggestions.filter { $0.sourceNoteID == sourceNote.id }
    }

    public func answer(prompt: String, mode: AnswerMode, context: [Note]) throws -> String {
        let titles = context.map(\.title).joined(separator: ", ")
        return "\(mode.label): \(prompt) [\(titles)]"
    }

    public func generatedNoteBodies(prompt: String, destinationCount: Int) throws -> AIWriteAdapterResult {
        switch generatedNoteBodiesResult {
        case .completed(let bodies) where bodies.isEmpty:
            return .completed(Array(repeating: prompt, count: destinationCount))
        default:
            return generatedNoteBodiesResult
        }
    }

    public func summary(for notes: [Note], progress: (AIProgressState) -> Void) throws -> String {
        progress(.loadingModel)
        try onSummaryProgress?(.loadingModel)
        progress(.generating)
        try onSummaryProgress?(.generating)
        if let summaryResult {
            return summaryResult
        }
        let sourceText = notes.map { "\($0.title): \($0.body)" }.joined(separator: "\n")
        return "Summary Output:\n\(sourceText)"
    }
}

private final class FakeAIRuntimeModelAvailabilityScript {
    private let responses: [AIRuntimeModelAvailability]
    private var nextResponseIndex = 0

    init(_ responses: [AIRuntimeModelAvailability]) {
        self.responses = responses.isEmpty ? [
            AIRuntimeModelAvailability(
                isAIReady: false,
                inventory: ModelInventory(downloadedProfiles: [], defaultProfileID: nil)
            )
        ] : responses
    }

    func next() -> AIRuntimeModelAvailability {
        defer {
            if nextResponseIndex < responses.count - 1 {
                nextResponseIndex += 1
            }
        }
        return responses[nextResponseIndex]
    }
}
