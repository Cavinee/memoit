public struct ExplicitLink: Equatable, Sendable {
    public let sourceNoteID: NoteID
    public let targetNoteID: NoteID
    public let snippet: String

    public init(sourceNoteID: NoteID, targetNoteID: NoteID, snippet: String) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.snippet = snippet
    }
}
