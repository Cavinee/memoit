public struct CreateNoteCommand: Equatable, Sendable {
    public let noteID: NoteID?
    public let title: String
    public let body: String
    public let creationProvenance: CreationProvenance

    public init(noteID: NoteID? = nil, title: String, body: String, creationProvenance: CreationProvenance) {
        self.noteID = noteID
        self.title = title
        self.body = body
        self.creationProvenance = creationProvenance
    }
}

public struct UpdateNoteBodyCommand: Equatable, Sendable {
    public let noteID: NoteID
    public let body: String

    public init(noteID: NoteID, body: String) {
        self.noteID = noteID
        self.body = body
    }
}

public struct RenameNoteCommand: Equatable, Sendable {
    public let noteID: NoteID
    public let title: String

    public init(noteID: NoteID, title: String) {
        self.noteID = noteID
        self.title = title
    }
}

public struct MoveNoteToTrashCommand: Equatable, Sendable {
    public let noteID: NoteID

    public init(noteID: NoteID) {
        self.noteID = noteID
    }
}

public struct SetPinnedNoteCommand: Equatable, Sendable {
    public let noteID: NoteID
    public let isPinned: Bool

    public init(noteID: NoteID, isPinned: Bool) {
        self.noteID = noteID
        self.isPinned = isPinned
    }
}

public struct TrashUndoOpportunity: Equatable, Sendable {
    public let noteID: NoteID

    public init(noteID: NoteID) {
        self.noteID = noteID
    }
}

public struct UndoTrashCommand: Equatable, Sendable {
    public let opportunity: TrashUndoOpportunity

    public init(opportunity: TrashUndoOpportunity) {
        self.opportunity = opportunity
    }
}

public struct RestoreNoteFromTrashCommand: Equatable, Sendable {
    public let noteID: NoteID

    public init(noteID: NoteID) {
        self.noteID = noteID
    }
}

public struct DeletionConfirmation: Equatable, Sendable {
    public let noteID: NoteID

    public init(noteID: NoteID) {
        self.noteID = noteID
    }
}

public struct PermanentlyDeleteNoteCommand: Equatable, Sendable {
    public let noteID: NoteID
    public let deletionConfirmation: DeletionConfirmation?

    public init(noteID: NoteID, deletionConfirmation: DeletionConfirmation?) {
        self.noteID = noteID
        self.deletionConfirmation = deletionConfirmation
    }
}

/// Which indexes a `runIndexingJobs` command rebuilds. `lexicalOnly` is the cheap,
/// main-thread "freshness" pass; `embeddingOnly` is the (potentially device-blocking)
/// semantic pass the app runs off the main thread. `all` rebuilds both and is the
/// default so existing call sites keep their original behavior.
public enum IndexingScope: Equatable, Sendable {
    case all
    case lexicalOnly
    case embeddingOnly
}

public struct RunIndexingJobsCommand: Equatable, Sendable {
    public let scope: IndexingScope

    public init(scope: IndexingScope = .all) {
        self.scope = scope
    }
}

public struct MarkdownExportFile: Equatable, Sendable {
    public let path: String
    public let body: String

    public init(path: String, body: String) {
        self.path = path
        self.body = body
    }
}

public typealias MarkdownImportFile = MarkdownExportFile

public struct MarkdownImportResult: Equatable, Sendable {
    public let notes: [Note]
    public let provenance: [NoteID: ImportProvenance]

    public init(notes: [Note], provenance: [NoteID: ImportProvenance]) {
        self.notes = notes
        self.provenance = provenance
    }
}

public struct ImportMarkdownFileCommand: Equatable, Sendable {
    public let file: MarkdownImportFile

    public init(file: MarkdownImportFile) {
        self.file = file
    }
}

public struct ImportMarkdownFolderCommand: Equatable, Sendable {
    public let files: [MarkdownImportFile]

    public init(files: [MarkdownImportFile]) {
        self.files = files
    }
}

public struct MarkdownExportOptions: Equatable, Sendable {
    public let includeTrash: Bool
    public let includeAISessionHistory: Bool
    public let includeEditProvenance: Bool

    public init(includeTrash: Bool = false, includeAISessionHistory: Bool = false, includeEditProvenance: Bool = false) {
        self.includeTrash = includeTrash
        self.includeAISessionHistory = includeAISessionHistory
        self.includeEditProvenance = includeEditProvenance
    }
}

public struct MarkdownExportResult: Equatable, Sendable {
    public let files: [MarkdownExportFile]
    public let manifest: MarkdownExportManifest

    public init(files: [MarkdownExportFile], manifest: MarkdownExportManifest) {
        self.files = files
        self.manifest = manifest
    }
}

public struct SingleNoteShare: Equatable, Sendable {
    public let title: String
    public let filename: String
    public let content: String

    public init(title: String, filename: String, content: String) {
        self.title = title
        self.filename = filename
        self.content = content
    }
}

public struct MarkdownExportManifest: Equatable, Sendable {
    public let noteIDsByPath: [String: NoteID]
    public let explicitLinks: [ExplicitLink]
    public let acceptedRelationships: [AcceptedRelationship]
    public let importProvenanceByPath: [String: ImportProvenance]
    public let editProvenance: [AIOperation]

    public init(noteIDsByPath: [String: NoteID] = [:], explicitLinks: [ExplicitLink] = [], acceptedRelationships: [AcceptedRelationship] = [], importProvenanceByPath: [String: ImportProvenance] = [:], editProvenance: [AIOperation] = []) {
        self.noteIDsByPath = noteIDsByPath
        self.explicitLinks = explicitLinks
        self.acceptedRelationships = acceptedRelationships
        self.importProvenanceByPath = importProvenanceByPath
        self.editProvenance = editProvenance
    }
}

public struct MarkdownExportBundle: Equatable, Sendable {
    public let files: [MarkdownExportFile]
    public let manifest: MarkdownExportManifest
    public let aiSessionHistory: [AISessionHistoryEntry]

    public init(files: [MarkdownExportFile], manifest: MarkdownExportManifest = .init(), aiSessionHistory: [AISessionHistoryEntry] = []) {
        self.files = files
        self.manifest = manifest
        self.aiSessionHistory = aiSessionHistory
    }
}

public struct ImportExportBundleCommand: Equatable, Sendable {
    public let bundle: MarkdownExportBundle

    public init(bundle: MarkdownExportBundle) {
        self.bundle = bundle
    }
}

public struct RunRelationshipScanCommand: Equatable, Sendable {
    public let noteID: NoteID

    public init(noteID: NoteID) {
        self.noteID = noteID
    }
}

public struct CreateAcceptedRelationshipCommand: Equatable, Sendable {
    public let sourceNoteID: NoteID
    public let targetNoteID: NoteID

    public init(sourceNoteID: NoteID, targetNoteID: NoteID) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
    }
}

public struct PromoteSuggestedRelationshipCommand: Equatable, Sendable {
    public let suggestedRelationship: SuggestedRelationship

    public init(suggestedRelationship: SuggestedRelationship) {
        self.suggestedRelationship = suggestedRelationship
    }
}

public struct RecordLocalModelProfileCommand: Equatable, Sendable {
    public let profile: LocalModelProfile

    public init(profile: LocalModelProfile) {
        self.profile = profile
    }
}

public struct SetDefaultLocalModelProfileCommand: Equatable, Sendable {
    public let profileID: LocalModelProfileID

    public init(profileID: LocalModelProfileID) {
        self.profileID = profileID
    }
}

public struct ClearDefaultLocalModelProfileCommand: Equatable, Sendable {
    public init() {}
}

public struct RemoveLocalModelProfileCommand: Equatable, Sendable {
    public let profileID: LocalModelProfileID

    public init(profileID: LocalModelProfileID) {
        self.profileID = profileID
    }
}

public struct RefreshModelAvailabilityFromAdapterCommand: Equatable, Sendable {
    public init() {}
}

public struct DeleteAISessionHistoryEntryCommand: Equatable, Sendable {
    public let entryID: AISessionHistoryEntryID

    public init(entryID: AISessionHistoryEntryID) {
        self.entryID = entryID
    }
}

public struct SaveAIResponseCommand: Equatable, Sendable {
    public let response: String
    public let destination: SavedAIResponseDestination

    public init(response: String, destination: SavedAIResponseDestination) {
        self.response = response
        self.destination = destination
    }
}

public struct SetAIEditingPermissionCommand: Equatable, Sendable {
    public let permission: AIEditingPermission

    public init(permission: AIEditingPermission) {
        self.permission = permission
    }
}

public struct RunAIWriteWorkflowCommand: Equatable, Sendable {
    public let sessionID: AISessionID
    public let prompt: String
    public let destinations: [AIWriteDestination]?

    public init(sessionID: AISessionID, prompt: String, destination: AIWriteDestination?) {
        self.sessionID = sessionID
        self.prompt = prompt
        self.destinations = destination.map { [$0] }
    }

    public init(sessionID: AISessionID, prompt: String, destinations: [AIWriteDestination]?) {
        self.sessionID = sessionID
        self.prompt = prompt
        self.destinations = destinations
    }
}

public struct AcceptDraftChangeCommand: Equatable, Sendable {
    public let draftChangeID: DraftChangeID

    public init(draftChangeID: DraftChangeID) {
        self.draftChangeID = draftChangeID
    }
}

public struct CancelDraftChangeCommand: Equatable, Sendable {
    public let draftChangeID: DraftChangeID

    public init(draftChangeID: DraftChangeID) {
        self.draftChangeID = draftChangeID
    }
}

public struct BeginIncompleteAIOperationCommand: Equatable, Sendable {
    public let localModelProfileID: LocalModelProfileID?
    public let changes: [AIChange]

    public init(localModelProfileID: LocalModelProfileID?, changes: [AIChange]) {
        self.localModelProfileID = localModelProfileID
        self.changes = changes
    }
}

public struct SimulateCrashRestartCommand: Equatable, Sendable {
    public init() {}
}

public struct SimulateIncompleteAIWriteWorkflowCommand: Equatable, Sendable {
    public let workflow: RunAIWriteWorkflowCommand

    public init(workflow: RunAIWriteWorkflowCommand) {
        self.workflow = workflow
    }
}

public struct SimulateIncompleteDraftAcceptanceCommand: Equatable, Sendable {
    public let draftChangeID: DraftChangeID

    public init(draftChangeID: DraftChangeID) {
        self.draftChangeID = draftChangeID
    }
}

public struct FailNextAIOperationCommitCommand: Equatable, Sendable {
    public init() {}
}

public struct ReverseAIOperationCommand: Equatable, Sendable {
    public let operationID: AIOperationID

    public init(operationID: AIOperationID) {
        self.operationID = operationID
    }
}

public enum RuntimeCommandSource: Equatable, Sendable {
    case user
    case ai
}

public enum RuntimeCommand: Equatable, Sendable {
    case createNote(CreateNoteCommand)
    case updateNoteBody(UpdateNoteBodyCommand)
    case renameNote(RenameNoteCommand)
    case moveNoteToTrash(MoveNoteToTrashCommand)
    case setPinnedNote(SetPinnedNoteCommand)
    case undoTrash(UndoTrashCommand)
    case restoreNoteFromTrash(RestoreNoteFromTrashCommand)
    case permanentlyDeleteNote(PermanentlyDeleteNoteCommand)
    case runIndexingJobs(RunIndexingJobsCommand)
    case importMarkdownFile(ImportMarkdownFileCommand)
    case importMarkdownFolder(ImportMarkdownFolderCommand)
    case importExportBundle(ImportExportBundleCommand)
    case runRelationshipScan(RunRelationshipScanCommand)
    case createAcceptedRelationship(CreateAcceptedRelationshipCommand)
    case promoteSuggestedRelationship(PromoteSuggestedRelationshipCommand)
    case recordLocalModelProfile(RecordLocalModelProfileCommand)
    case setDefaultLocalModelProfile(SetDefaultLocalModelProfileCommand)
    case clearDefaultLocalModelProfile(ClearDefaultLocalModelProfileCommand)
    case removeLocalModelProfile(RemoveLocalModelProfileCommand)
    case refreshModelAvailabilityFromAdapter(RefreshModelAvailabilityFromAdapterCommand)
    case deleteAISessionHistoryEntry(DeleteAISessionHistoryEntryCommand)
    case saveAIResponse(SaveAIResponseCommand)
    case setAIEditingPermission(SetAIEditingPermissionCommand)
    case runAIWriteWorkflow(RunAIWriteWorkflowCommand)
    case acceptDraftChange(AcceptDraftChangeCommand)
    case cancelDraftChange(CancelDraftChangeCommand)
    case beginIncompleteAIOperation(BeginIncompleteAIOperationCommand)
    case simulateCrashRestart(SimulateCrashRestartCommand)
    case simulateIncompleteAIWriteWorkflow(SimulateIncompleteAIWriteWorkflowCommand)
    case simulateIncompleteDraftAcceptance(SimulateIncompleteDraftAcceptanceCommand)
    case failNextAIOperationCommit(FailNextAIOperationCommitCommand)
    case reverseAIOperation(ReverseAIOperationCommand)
}

extension RuntimeCommand {
    var isForbiddenForAI: Bool {
        switch self {
        case .runIndexingJobs, .runRelationshipScan, .runAIWriteWorkflow:
            return false
        default:
            return true
        }
    }
}

public enum RuntimeCommandResult: Equatable, Sendable {
    case createdNote(Note)
    case discardedEmptyNote
    case updatedNote(Note)
    case renamedNote(Note)
    case movedNoteToTrash(Note, TrashUndoOpportunity)
    case restoredNote(Note)
    case permanentlyDeletedNote(NoteID)
    case ranIndexingJobs
    case importedMarkdown(MarkdownImportResult)
    case suggestedRelationships([SuggestedRelationship])
    case createdAcceptedRelationship(AcceptedRelationship)
    case recordedLocalModelProfile(LocalModelProfile)
    case updatedModelInventory(ModelInventory)
    case deletedAISessionHistoryEntry(AISessionHistoryEntryID)
    case savedAIResponse(SavedAIResponse)
    case setAIEditingPermission(AIEditingPermission)
    case aiWriteWorkflow(AIWriteWorkflowResult)
    case acceptedDraftChange(AIOperation)
    case canceledDraftChange(DraftChangeID)
    case beganIncompleteAIOperation(AIOperationID)
    case simulatedCrashRestart
    case configuredAIOperationCommitFailure
    case reversedAIOperation(AIOperation)
}
