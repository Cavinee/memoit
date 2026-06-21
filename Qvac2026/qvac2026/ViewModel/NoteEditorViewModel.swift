//
//  NoteEditorViewModel.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI
import PhotosUI
import UIKit
import Combine
import QVACRuntime

// MARK: - Supporting types

enum NoteToolbarMode { case main, formatting, list, recording, table }

struct DisplayImage: Identifiable {
    let id: UUID
    let image: UIImage
}

struct PreviewFile: Identifiable {
    let id: UUID
    let url: URL
}

// MARK: - NoteEditorViewModel

@MainActor
final class NoteEditorViewModel: ObservableObject {
    private static let defaultTitle = "Untitled Note"
    
    // MARK: Note identity
    
    let noteId: UUID
    @Published var noteTitle: String
    @Published var updatedAt: Date?
    
    // MARK: Rich-text editor
    
    let editor = RichTextController()
    
    // MARK: Attachments

    @Published var fileAttachments:        [Attachment] = []   // Future Attachments are disabled in v1.
    @Published var persistedAttachmentIds: Set<UUID>    = []
    
    // MARK: Image viewer

    @Published var presentedImage: DisplayImage?

    // MARK: File preview

    @Published var presentedFile: PreviewFile?
    
    // MARK: Toolbar / rename UI

    @Published var activeToolbar: NoteToolbarMode = .main
    @Published var showRename    = false
    @Published var renameText    = ""
    @Published var showSaveError = false
    /// Drives the "Find Related Notes" sheet from the note's 3-dots menu.
    @Published var relatedResult: RelatedNotesResult?
    /// Drives the inline "@" mention surface (also opened by the link toolbar button).
    @Published var showNoteLinkPicker = false
    /// Drives the inline "/" slash command surface.
    @Published var showSlashMenu = false
    @Published private(set) var saveErrorMessage = ""

    // MARK: Table cell focus tracking

    /// The table attachment whose cell is currently being edited, if any.
    @Published var focusedTable: TableTextAttachment? = nil
    /// The row/column of the cell currently being edited.
    @Published var focusedCell: (row: Int, col: Int)? = nil
    /// Incremented on each begin-edit; used to cancel stale end-edit deferrals.
    private var cellEditingToken = 0
    /// Cached UIHostingController for the table cell input accessory view.
    private var tableCellAccessoryHosting: UIHostingController<NoteKeyboardToolbar>?
    
    // MARK: Recording
    
    @Published var isRecording      = false
    @Published var recordingSeconds = 0
    private var recordingTimer: Timer?
    private var currentRecordingFilename: String?
    private let audioRecorder = AudioRecorderService()
    
    // MARK: Pickers
    
    @Published var showPhotoPicker  = false
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var showFilePicker   = false
    @Published var showCameraPicker = false
    
    // MARK: Persistence flags
    
    private var persistedNoteExists: Bool
    private var suppressAutosave    = false
    @Published private var hasChanges = false
    private var titleWasManuallySet = false

    var hasUnsavedChanges: Bool {
        hasChanges
    }
    
    // MARK: Editor republish
    
    private var editorCancellable: AnyCancellable?
    
    // MARK: Init
    
    init(blankWithId id: UUID = UUID()) {
        self.noteId    = id
        self.noteTitle = Self.defaultTitle
        self.updatedAt = nil
        self.persistedNoteExists = false
        bindEditor()
    }
    
    init(note: Note) {
        self.noteId    = note.id
        self.noteTitle = note.title
        self.updatedAt = note.updatedAt
        self.persistedNoteExists    = true
        self.titleWasManuallySet    = note.title != "Untitled Note"
        bindEditor()
    }
    
    private func bindEditor() {
        editorCancellable = editor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: Content loading
    
    /// Loads note content into the editor and reconnects inline attachment hosts.
    /// Replaces direct calls to `editor.loadInitialContent` in the views.
    func loadContent(note: Note?) {
        editor.loadInitialContent(note: note)
        if note != nil {
            loadPersistedAttachments()
        }
        // Reconnect host on any inline attachments restored from the archive
        editor.attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: editor.attributedText.length),
            options: []
        ) { [weak self] value, _, _ in
            (value as? AudioTextAttachment)?.host = self
            (value as? ImageTextAttachment)?.host = self
            (value as? FileTextAttachment)?.host  = self
            (value as? TableTextAttachment)?.host  = self
        }
    }
    
    // MARK: Persistence
    
    @discardableResult
    func persist() -> Bool {
        guard !suppressAutosave else { return true }
        guard TextFirstV1AppGuard.canPersistNoteTextInput() else { return true }
        
        // Strip object-replacement chars from presentation text while saving the
        // runtime-owned Supported Markdown Note Body through the formatter.
        let visibleText = editor.attributedText.string
            .replacingOccurrences(of: "\u{FFFC}", with: "")
        let body = editor.supportedMarkdownBody()
        let hasInlineAttachment = editor.attributedText.string.contains("\u{FFFC}")
        let hasInlineAudio = hasInlineAttachment
        let trimmedEmpty = visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let titleForDiscard = (!titleWasManuallySet && noteTitle == Self.defaultTitle) ? "" : noteTitle
        
        if !hasInlineAudio &&
            !persistedNoteExists &&
            UserCreatedNoteDraftDiscardPolicy.shouldDiscard(title: titleForDiscard, body: visibleText) {
            return true
        }
        
        // Auto-derive title from first non-empty line until the user manually renames.
        if !titleWasManuallySet && !trimmedEmpty {
            let derived = Self.derivedTitle(from: visibleText)
            if derived != noteTitle { noteTitle = derived }
        }
        
        // Presentation cache only. The runtime Note Body above remains authoritative.
        let bodyData = try? NSKeyedArchiver.archivedData(
            withRootObject: editor.attributedText,
            requiringSecureCoding: false
        )
        
        if let saved = KnowledgeRuntimeService.shared.saveNote(
            id: noteId,
            title: noteTitle,
            body: body,
            contentRTF: bodyData,
            type: .text
        ) {
            if saved.title != noteTitle {
                noteTitle = saved.title
            }
            persistedNoteExists = true
            updatedAt = saved.updatedAt
            hasChanges = false
            saveErrorMessage = ""
            showSaveError = false
            return true
        }
        hasChanges = true
        saveErrorMessage = "This note could not be saved. Keep the editor open and try again."
        showSaveError = true
        return false
    }
    
    private static func derivedTitle(from text: String) -> String {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !firstLine.isEmpty else { return defaultTitle }
        return String(firstLine.prefix(50))
    }
    
    @discardableResult
    func persistIfChanged() -> Bool {
        hasChanges ? persist() : true
    }
    
    /// Called from the Rename alert. Locks the title so body edits no longer overwrite it.
    func applyManualRename(_ newTitle: String) {
        titleWasManuallySet = true
        noteTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func markChanged() {
        hasChanges = true
    }

    func insertWikilink(to note: Note) {
        guard let wikilink = SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: note.title) else {
            return
        }

        editor.insertWikilink(title: note.title, markdown: wikilink)
        markChanged()
        persist()
    }

    /// Inserts plain text (e.g. a date from the slash menu) at the caret.
    /// The debounced editor autosave persists the change.
    func insertText(_ text: String) {
        editor.insertPlainText(text)
        markChanged()
    }

    /// Closes both inline command surfaces (`@` mention and `/` slash).
    func dismissCommandMenus() {
        showNoteLinkPicker = false
        showSlashMenu = false
    }
    
    func moveToTrash() {
        suppressAutosave = true
        KnowledgeRuntimeService.shared.moveToTrash(id: noteId)
    }

    /// Finds notes related to the open note via on-device embedding similarity and
    /// presents them in the related-notes sheet. No generation worklet, no `.qvac` path.
    func findRelated() {
        relatedResult = RelatedNotesResult(
            sourceTitle: noteTitle,
            related: KnowledgeRuntimeService.shared.relatedNotes(to: noteId)
        )
    }

    // MARK: Attachments

    func loadPersistedAttachments() {
        guard TextFirstV1AppGuard.canLoadPersistedAttachments() else {
            fileAttachments = []
            persistedAttachmentIds = []
            return
        }

        let loaded = DatabaseService.shared.attachments.fetch(forNoteId: noteId)
        fileAttachments = []
        persistedAttachmentIds = Set(loaded.map { $0.id })
    }

    // MARK: Recording
    
    func startRecording() {
        guard TextFirstV1AppGuard.canStartRecording() else { return }

        Task {
            let granted = await audioRecorder.requestPermission()
            guard granted else { return }
            do {
                let filename = try audioRecorder.start()
                currentRecordingFilename = filename
            } catch {
                print("NoteEditorViewModel: recorder start error: \(error)")
                return
            }
            isRecording = true
            activeToolbar = .recording
            recordingSeconds = 0
            recordingTimer?.invalidate()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                MainActor.assumeIsolated { self.recordingSeconds += 1 }
            }
        }
    }
    
    func stopRecording() {
        guard TextFirstV1AppGuard.canStopRecordingAndCreateAttachment() else {
            cancelRecording()
            return
        }

        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        activeToolbar = .main
        
        guard let filename = currentRecordingFilename else { return }
        currentRecordingFilename = nil
        
        let (durationMs, sizeBytes) = audioRecorder.stop()
        let attachment = Attachment(
            noteId:     noteId,
            type:       .audio,
            filename:   filename,
            filePath:   filename,      // relative name resolved via AudioService.url(forRelative:)
            sizeBytes:  sizeBytes,
            durationMs: max(durationMs, recordingSeconds * 1000),
            createdAt:  .now
        )
        
        // Persist the attachment row immediately (inline insert + body archive happen in persist())
        DatabaseService.shared.attachments.insert(attachment)
        persistedAttachmentIds.insert(attachment.id)
        
        // Insert the card inline in the editor and save
        editor.insertAudio(attachment, host: self)
        markChanged()
        persist()
    }
    
    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        activeToolbar = .main
        audioRecorder.cancel()
        currentRecordingFilename = nil
    }
    
    // MARK: Formatting helpers
    
    var recordingTimeString: String {
        String(format: "%d:%02d", recordingSeconds / 60, recordingSeconds % 60)
    }
    
    var formattedDate: String {
        guard let date = updatedAt else { return "Not saved yet" }
        let fmt = DateFormatter()
        fmt.dateFormat = Calendar.current.isDateInToday(date)
        ? "'Last updated, Today,' HH:mm"
        : "'Last updated,' MMM d, HH:mm"
        return fmt.string(from: date)
    }

    // MARK: Images

    /// Saves `image` to disk, inserts it inline in the editor, and persists.
    func addImage(_ image: UIImage) {
        guard TextFirstV1AppGuard.canAddImageAttachment() else { return }

        guard let relativeName = ImageService.save(image) else { return }
        let sizeBytes = (try? FileManager.default
            .attributesOfItem(atPath: ImageService.url(forRelative: relativeName).path)[.size]
            as? Int64) ?? 0
        let attachment = Attachment(
            noteId:    noteId,
            type:      .image,
            filename:  relativeName,
            filePath:  relativeName,
            mimeType:  "image/jpeg",
            sizeBytes: sizeBytes,
            createdAt: .now
        )
        DatabaseService.shared.attachments.insert(attachment)
        persistedAttachmentIds.insert(attachment.id)
        editor.insertImage(attachment, host: self)
        markChanged()
        persist()
    }

    /// Inserts a Supported Markdown table at the current cursor position and persists.
    func insertTable() {
        guard TextFirstV1AppGuard.canInsertMarkdownTable() else { return }

        editor.insertTable(host: self)
        markChanged()
        persist()
    }

    /// Copies the file at `sourceURL` into app storage, inserts it inline, and persists.
    /// The caller must hold a security-scoped resource access for `sourceURL`.
    func addFile(from sourceURL: URL) {
        guard TextFirstV1AppGuard.canAddFileAttachment() else { return }

        guard let (relativeName, displayName, sizeBytes) = FileService.save(from: sourceURL) else { return }
        let attachment = Attachment(
            noteId:    noteId,
            type:      .file,
            filename:  displayName,
            filePath:  relativeName,
            sizeBytes: sizeBytes,
            createdAt: .now
        )
        DatabaseService.shared.attachments.insert(attachment)
        persistedAttachmentIds.insert(attachment.id)
        editor.insertFile(attachment, host: self)
        markChanged()
        persist()
    }
}

// MARK: - AudioAttachmentHosting

extension NoteEditorViewModel: AudioAttachmentHosting {
    
    func deleteInlineAudio(id: UUID) {
        // Look up the attachment to get the file path before deleting the DB row
        if let att = DatabaseService.shared.attachments.fetch(id: id) {
            DatabaseService.shared.attachments.delete(id: id)
            AudioService.delete(relativeName: att.filePath)
        }
        persistedAttachmentIds.remove(id)
        editor.removeAudioAttachment(audioId: id.uuidString)
        markChanged()
        persist()
    }
}

// MARK: - ImageAttachmentHosting

extension NoteEditorViewModel: ImageAttachmentHosting {

    func openInlineImage(id: UUID) {
        guard let att = DatabaseService.shared.attachments.fetch(id: id),
              let img = ImageService.load(relativeName: att.filePath) else { return }
        presentedImage = DisplayImage(id: id, image: img)
    }

    func deleteInlineImage(id: UUID) {
        if let att = DatabaseService.shared.attachments.fetch(id: id) {
            DatabaseService.shared.attachments.delete(id: id)
            ImageService.delete(relativeName: att.filePath)
        }
        persistedAttachmentIds.remove(id)
        editor.removeImageAttachment(imageId: id.uuidString)
        markChanged()
        persist()
    }
}

// MARK: - FileAttachmentHosting

extension NoteEditorViewModel: FileAttachmentHosting {

    func openInlineFile(id: UUID) {
        guard let att = DatabaseService.shared.attachments.fetch(id: id) else { return }
        let fileURL = FileService.url(forRelative: att.filePath)
        presentedFile = PreviewFile(id: id, url: fileURL)
    }

    func deleteInlineFile(id: UUID) {
        if let att = DatabaseService.shared.attachments.fetch(id: id) {
            DatabaseService.shared.attachments.delete(id: id)
            FileService.delete(relativeName: att.filePath)
        }
        persistedAttachmentIds.remove(id)
        editor.removeFileAttachment(fileId: id.uuidString)
        markChanged()
        persist()
    }
}

// MARK: - TableAttachmentHosting

extension NoteEditorViewModel: TableAttachmentHosting {

    // MARK: Protocol: content / layout change

    /// A cell's text changed — persist the note (no layout refresh needed).
    func tableContentDidChange() {
        markChanged()
        persist()
    }

    /// Kept for protocol conformance. Structural edits now go through the dedicated
    /// insert/delete methods below, which call `rebuild(focusing:)` directly.
    func tableLayoutDidChange() {
        markChanged()
        persist()
    }

    // MARK: Protocol: cell focus

    func tableCellDidBeginEditing(_ att: TableTextAttachment, row: Int, col: Int) {
        cellEditingToken += 1
        focusedTable   = att
        focusedCell    = (row, col)
        activeToolbar  = .table
        // Keep the floating bar hidden and show the "done" checkmark.
        editor.isFocused = true
    }

    func tableCellDidEndEditing(_ att: TableTextAttachment) {
        // Defer so that cell→cell transitions within the same table don't flip the
        // toolbar back to .main. If a new begin-edit fires within the delay, the token
        // will have advanced and this closure becomes a no-op.
        let token = cellEditingToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.cellEditingToken == token else { return }
            self.focusedTable   = nil
            self.focusedCell    = nil
            self.activeToolbar  = .main
            self.editor.isFocused = false
        }
    }

    // MARK: Protocol: shared accessory view

    /// Returns a stable `UIView` for all cell `inputAccessoryView`s. The underlying
    /// `UIHostingController` is kept alive in `tableCellAccessoryHosting`.
    func tableCellAccessoryView() -> UIView {
        if let host = tableCellAccessoryHosting { return host.view }
        let host = UIHostingController(rootView: NoteKeyboardToolbar(state: self))
        host.view.frame = CGRect(x: 0, y: 0, width: 0, height: 48)
        host.view.autoresizingMask = [.flexibleWidth]
        host.view.backgroundColor = .clear
        tableCellAccessoryHosting = host
        return host.view
    }

    // MARK: Table structural edits

    /// Inserts a blank row above the currently focused row.
    func insertRowAbove() {
        guard let att = focusedTable, let cell = focusedCell else { return }
        let cols = att.cells.first?.count ?? 2
        att.cells.insert(Array(repeating: "", count: cols), at: cell.row)
        let newFocus = (row: cell.row, col: cell.col)
        focusedCell = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }

    /// Inserts a blank row below the currently focused row.
    func insertRowBelow() {
        guard let att = focusedTable, let cell = focusedCell else { return }
        let cols = att.cells.first?.count ?? 2
        att.cells.insert(Array(repeating: "", count: cols), at: cell.row + 1)
        let newFocus = (row: cell.row + 1, col: cell.col)
        focusedCell = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }

    /// Inserts a blank column to the left of the currently focused column.
    func insertColumnLeft() {
        guard let att = focusedTable, let cell = focusedCell else { return }
        for i in att.cells.indices { att.cells[i].insert("", at: cell.col) }
        let newFocus = (row: cell.row, col: cell.col)
        focusedCell = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }

    /// Inserts a blank column to the right of the currently focused column.
    func insertColumnRight() {
        guard let att = focusedTable, let cell = focusedCell else { return }
        for i in att.cells.indices { att.cells[i].insert("", at: cell.col + 1) }
        let newFocus = (row: cell.row, col: cell.col + 1)
        focusedCell = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }

    /// Deletes the currently focused row. No-op when only one row remains.
    func deleteRow() {
        guard let att = focusedTable, let cell = focusedCell,
              att.cells.count > 1 else { return }
        att.cells.remove(at: cell.row)
        let newRow   = min(cell.row, att.cells.count - 1)
        let newCol   = min(cell.col, (att.cells.first?.count ?? 1) - 1)
        let newFocus = (row: newRow, col: newCol)
        focusedCell  = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }

    /// Deletes the currently focused column. No-op when only one column remains.
    func deleteColumn() {
        guard let att = focusedTable, let cell = focusedCell,
              (att.cells.first?.count ?? 0) > 1 else { return }
        for i in att.cells.indices { att.cells[i].remove(at: cell.col) }
        let newCol   = min(cell.col, (att.cells.first?.count ?? 1) - 1)
        let newFocus = (row: cell.row, col: newCol)
        focusedCell  = newFocus
        att.currentProvider?.rebuild(focusing: newFocus)
        markChanged(); persist()
    }
}
