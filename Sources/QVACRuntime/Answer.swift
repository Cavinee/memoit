public enum AnswerMode: Equatable, Sendable {
    case noteGrounded
    case general
}

extension AnswerMode {
    var label: String {
        switch self {
        case .noteGrounded:
            return "Note-grounded Answer"
        case .general:
            return "General AI Answer: not constrained to retrieved Notes"
        }
    }

    var isConstrainedToRetrievedNotes: Bool {
        self == .noteGrounded
    }
}

public struct AnswerRequest: Equatable, Sendable {
    public let prompt: String
    public let mode: AnswerMode

    public init(prompt: String, mode: AnswerMode = .noteGrounded) {
        self.prompt = prompt
        self.mode = mode
    }
}

public struct AnswerResult: Equatable, Sendable {
    public let answer: String
    public let mode: AnswerMode
    public let modeLabel: String
    public let isConstrainedToRetrievedNotes: Bool
    public let citations: [SourceCitation]

    public init(answer: String, mode: AnswerMode, modeLabel: String, isConstrainedToRetrievedNotes: Bool, citations: [SourceCitation]) {
        self.answer = answer
        self.mode = mode
        self.modeLabel = modeLabel
        self.isConstrainedToRetrievedNotes = isConstrainedToRetrievedNotes
        self.citations = citations
    }
}
