public struct DiagnosticsModelProfile: Equatable, Sendable {
    public let id: LocalModelProfileID
    public let name: String

    public init(id: LocalModelProfileID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DiagnosticsExport: Equatable, Sendable {
    public let noteIDs: [NoteID]
    public let activeNoteCount: Int
    public let trashedNoteCount: Int
    public let placeholderNoteCount: Int
    public let explicitLinkCount: Int
    public let acceptedRelationshipCount: Int
    public let localModelProfiles: [DiagnosticsModelProfile]
    public let chosenLocalModelProfileID: LocalModelProfileID?
    public let aiProgressState: AIProgressState
    public let aiOperationIDs: [AIOperationID]
    public let aiOperationCount: Int

    public init(noteIDs: [NoteID], activeNoteCount: Int, trashedNoteCount: Int, placeholderNoteCount: Int, explicitLinkCount: Int, acceptedRelationshipCount: Int, localModelProfiles: [DiagnosticsModelProfile], chosenLocalModelProfileID: LocalModelProfileID?, aiProgressState: AIProgressState, aiOperationIDs: [AIOperationID], aiOperationCount: Int) {
        self.noteIDs = noteIDs
        self.activeNoteCount = activeNoteCount
        self.trashedNoteCount = trashedNoteCount
        self.placeholderNoteCount = placeholderNoteCount
        self.explicitLinkCount = explicitLinkCount
        self.acceptedRelationshipCount = acceptedRelationshipCount
        self.localModelProfiles = localModelProfiles
        self.chosenLocalModelProfileID = chosenLocalModelProfileID
        self.aiProgressState = aiProgressState
        self.aiOperationIDs = aiOperationIDs
        self.aiOperationCount = aiOperationCount
    }
}

public enum ContentFreeLogField: String, CaseIterable, Hashable, Equatable, Sendable {
    case id
    case count
    case durationMilliseconds
    case modelProfileName
    case jobState
    case errorCategory
    case storageBytes
}

public enum ContentFreeLogValue: Equatable, Sendable {
    case string(String)
    case int(Int)
}

public struct ContentFreeLogEntry: Equatable, Sendable {
    public let fields: [ContentFreeLogField: ContentFreeLogValue]

    public init(fields: [ContentFreeLogField: ContentFreeLogValue]) {
        self.fields = fields
    }

    public init(validating fields: [String: ContentFreeLogValue]) throws {
        var accepted: [ContentFreeLogField: ContentFreeLogValue] = [:]
        for (name, value) in fields {
            let normalized = name.contentFreeFieldName
            guard !ContentFreeLogError.forbiddenFieldNames.contains(normalized),
                  let field = ContentFreeLogField.allCases.first(where: { $0.rawValue.contentFreeFieldName == normalized }) else {
                throw ContentFreeLogError.forbiddenField(name)
            }
            accepted[field] = value
        }
        self.fields = accepted
    }
}

public struct CrashReportPayload: Equatable, Sendable {
    public let errorCategory: String
    public let count: Int
    public let state: String

    public init(errorCategory: String, count: Int, state: String) {
        self.errorCategory = errorCategory
        self.count = count
        self.state = state
    }
}

public enum ContentFreeLogError: Error, Equatable, Sendable {
    case forbiddenField(String)

    static let forbiddenFieldNames: Set<String> = [
        "aisessionhistory",
        "body",
        "citation",
        "citations",
        "filename",
        "filenames",
        "filepath",
        "importpath",
        "label",
        "labels",
        "notebody",
        "notetext",
        "notetitle",
        "path",
        "prompt",
        "prompts",
        "response",
        "responses",
        "sourcecitation",
        "sourcecitations",
        "sourcepath",
        "text",
        "title"
    ]
}

private extension String {
    var contentFreeFieldName: String {
        lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
