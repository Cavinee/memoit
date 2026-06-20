public struct Backlink: Equatable, Sendable {
    public let sourceNoteID: NoteID
    public let sourceNoteTitle: String
    public let targetNoteID: NoteID
    public let snippet: String

    public init(sourceNoteID: NoteID, sourceNoteTitle: String, targetNoteID: NoteID, snippet: String) {
        self.sourceNoteID = sourceNoteID
        self.sourceNoteTitle = sourceNoteTitle
        self.targetNoteID = targetNoteID
        self.snippet = snippet
    }
}
