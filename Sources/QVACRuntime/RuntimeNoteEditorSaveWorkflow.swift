import Foundation

public enum RuntimeNoteEditorSaveWorkflowError: Error, Equatable, Sendable {
    case invalidWikilinkTitle(String)
    case invalidEditorTextRange(SupportedMarkdownEditorTextRange)
    case discardedEmptyNote
    case unexpectedRuntimeResult
}

public struct RuntimeNoteEditorSaveWorkflow: Equatable, Sendable {
    public let noteID: NoteID?
    public var title: String
    public var body: String

    public init(noteID: NoteID? = nil, title: String, body: String) {
        self.noteID = noteID
        self.title = title
        self.body = body
    }

    public mutating func insertWikilink(
        to note: Note,
        replacing range: SupportedMarkdownEditorTextRange
    ) throws {
        guard let wikilink = SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: note.title) else {
            throw RuntimeNoteEditorSaveWorkflowError.invalidWikilinkTitle(note.title)
        }

        let nsBody = body as NSString
        guard range.location >= 0,
              range.length >= 0,
              range.location + range.length <= nsBody.length else {
            throw RuntimeNoteEditorSaveWorkflowError.invalidEditorTextRange(range)
        }

        body = nsBody.replacingCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: wikilink
        )
    }

    public func save(into runtime: OnDeviceKnowledgeRuntime) throws -> Note {
        if let noteID,
           var current = try existingNote(noteID, in: runtime) {
            if current.title != title {
                current = try renamedNote(from: runtime.execute(.renameNote(.init(
                    noteID: noteID,
                    title: title
                ))))
            }
            if current.body != body {
                current = try updatedNote(from: runtime.execute(.updateNoteBody(.init(
                    noteID: noteID,
                    body: body
                ))))
            }
            return current
        }

        let result = try runtime.execute(.createNote(.init(
            noteID: noteID,
            title: title,
            body: body,
            creationProvenance: .userCreated
        )))
        switch result {
        case .createdNote(let note):
            return note
        case .discardedEmptyNote:
            throw RuntimeNoteEditorSaveWorkflowError.discardedEmptyNote
        default:
            throw RuntimeNoteEditorSaveWorkflowError.unexpectedRuntimeResult
        }
    }

    private func existingNote(_ noteID: NoteID, in runtime: OnDeviceKnowledgeRuntime) throws -> Note? {
        switch try runtime.query(.note(noteID)) {
        case .note(let note):
            return note
        default:
            throw RuntimeNoteEditorSaveWorkflowError.unexpectedRuntimeResult
        }
    }

    private func updatedNote(from result: RuntimeCommandResult) throws -> Note {
        switch result {
        case .updatedNote(let note):
            return note
        default:
            throw RuntimeNoteEditorSaveWorkflowError.unexpectedRuntimeResult
        }
    }

    private func renamedNote(from result: RuntimeCommandResult) throws -> Note {
        switch result {
        case .renamedNote(let note):
            return note
        default:
            throw RuntimeNoteEditorSaveWorkflowError.unexpectedRuntimeResult
        }
    }
}
