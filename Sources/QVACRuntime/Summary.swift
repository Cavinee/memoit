public enum SummaryDestination: Equatable, Sendable {
    case responseOnly
    case draftChange(noteID: NoteID)
    case newNote(title: String)
}

public enum SummarySource: Equatable, Sendable {
    case selectedNoteIDs([NoteID])
    case retrievedNotes(prompt: String)
}

public enum SummaryOutput: Equatable, Sendable {
    case responseOnly
    case draftChange(DraftChange)
    case newNote(Note, AIOperation)
}

public struct SummaryRequest: Equatable, Sendable {
    public let sessionID: AISessionID
    public let source: SummarySource
    public let destination: SummaryDestination

    public init(sessionID: AISessionID, sourceNoteIDs: [NoteID], destination: SummaryDestination) {
        self.sessionID = sessionID
        self.source = .selectedNoteIDs(sourceNoteIDs)
        self.destination = destination
    }

    public init(sessionID: AISessionID, prompt: String, destination: SummaryDestination) {
        self.sessionID = sessionID
        self.source = .retrievedNotes(prompt: prompt)
        self.destination = destination
    }
}

public struct SummaryResult: Equatable, Sendable {
    public let summary: String
    public let citations: [SourceCitation]
    public let output: SummaryOutput

    public init(summary: String, citations: [SourceCitation], output: SummaryOutput) {
        self.summary = summary
        self.citations = citations
        self.output = output
    }
}
