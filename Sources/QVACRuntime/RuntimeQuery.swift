public struct HomeNoteList: Equatable, Sendable {
    public let pinnedNotes: [Note]
    public let groups: [NoteListGroup]

    public init(pinnedNotes: [Note], groups: [NoteListGroup]) {
        self.pinnedNotes = pinnedNotes
        self.groups = groups
    }
}

public struct NoteListGroup: Equatable, Sendable {
    public let title: String
    public let notes: [Note]

    public init(title: String, notes: [Note]) {
        self.title = title
        self.notes = notes
    }
}

public enum RuntimeQuery: Equatable, Sendable {
    case note(NoteID)
    case notes
    case homeNotes
    case trashedNotes
    case explicitLinks(NoteID)
    case backlinks(NoteID)
    case trustedGraph
    case userSearch(String)
    case relatedNotes(NoteID)
    case indexFreshness(DerivedIndex)
    case aiReadyDevice
    case aiUnavailableState
    case modelInventory
    case chosenLocalModelProfile
    case aiProgressState
    case aiSessionHistory
    case aiOperations
    case markdownExport(MarkdownExportOptions)
    case exportBundle(MarkdownExportOptions)
    case singleNoteShare(NoteID)
    case diagnosticsExport
}

public enum RuntimeQueryResult: Equatable, Sendable {
    case note(Note?)
    case notes([Note])
    case homeNotes(HomeNoteList)
    case trashedNotes([Note])
    case explicitLinks([ExplicitLink])
    case backlinks([Backlink])
    case trustedGraph(TrustedGraph)
    case userSearchResults([Note])
    case relatedNotes([Note])
    case indexFreshness(IndexFreshness)
    case aiReadyDevice(Bool)
    case aiUnavailableState(AIUnavailableState?)
    case modelInventory(ModelInventory)
    case chosenLocalModelProfile(LocalModelProfile?)
    case aiProgressState(AIProgressState)
    case aiSessionHistory([AISessionHistoryEntry])
    case aiOperations([AIOperation])
    case markdownExport(MarkdownExportResult)
    case exportBundle(MarkdownExportBundle)
    case singleNoteShare(SingleNoteShare)
    case diagnosticsExport(DiagnosticsExport)
}
