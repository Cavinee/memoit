public enum TextFirstV1EntryPoint: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    case textInput
    case markdownTable
    case audioRecording
    case cameraCapture
    case photoPicker
    case documentFilePicker
    case microphone
    case ocr
    case transcription
    case attachment

    public var description: String {
        rawValue
    }
}

public enum TextFirstV1AppEntryPoint: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    case noteTextInput
    case noteMarkdownTable
    case noteStartRecording
    case noteStopRecording
    case noteAddImage
    case noteAddFile
    case noteCameraCapture
    case notePhotoPicker
    case noteMicrophone
    case notePersistedAttachments
    case chatAttachment
    case chatMicrophone

    public var description: String {
        rawValue
    }
}

public struct TextFirstV1AppEntryDecision: Equatable, Sendable {
    public let entryPoint: TextFirstV1AppEntryPoint
    public let isEnabled: Bool
    public let allowsAttachmentRecordCreation: Bool
    public let allowsRuntimeNoteBodyMutation: Bool

    public init(
        entryPoint: TextFirstV1AppEntryPoint,
        isEnabled: Bool,
        allowsAttachmentRecordCreation: Bool,
        allowsRuntimeNoteBodyMutation: Bool
    ) {
        self.entryPoint = entryPoint
        self.isEnabled = isEnabled
        self.allowsAttachmentRecordCreation = allowsAttachmentRecordCreation
        self.allowsRuntimeNoteBodyMutation = allowsRuntimeNoteBodyMutation
    }
}

public enum TextFirstV1AppGuard {
    public static func decision(for entryPoint: TextFirstV1AppEntryPoint) -> TextFirstV1AppEntryDecision {
        TextFirstV1AppEntryDecision(
            entryPoint: entryPoint,
            isEnabled: TextFirstV1Policy.isEnabled(entryPoint),
            allowsAttachmentRecordCreation: TextFirstV1Policy.allowsAttachmentRecordCreation(from: entryPoint),
            allowsRuntimeNoteBodyMutation: TextFirstV1Policy.allowsRuntimeNoteBodyMutation(from: entryPoint)
        )
    }

    public static func canPersistNoteTextInput() -> Bool {
        decision(for: .noteTextInput).allowsRuntimeNoteBodyMutation
    }

    public static func canInsertMarkdownTable() -> Bool {
        decision(for: .noteMarkdownTable).allowsRuntimeNoteBodyMutation
    }

    public static func canLoadPersistedAttachments() -> Bool {
        decision(for: .notePersistedAttachments).allowsAttachmentRecordCreation
    }

    public static func canStartRecording() -> Bool {
        decision(for: .noteStartRecording).isEnabled
    }

    public static func canStopRecordingAndCreateAttachment() -> Bool {
        decision(for: .noteStopRecording).allowsAttachmentRecordCreation
    }

    public static func canAddImageAttachment() -> Bool {
        decision(for: .noteAddImage).allowsAttachmentRecordCreation
    }

    public static func canAddFileAttachment() -> Bool {
        decision(for: .noteAddFile).allowsAttachmentRecordCreation
    }

    public static func canUseChatMicrophone() -> Bool {
        decision(for: .chatMicrophone).isEnabled
    }

    public static func canUseChatAttachment() -> Bool {
        decision(for: .chatAttachment).isEnabled
    }
}

public enum TextFirstV1Policy {
    public static func isEnabled(_ entryPoint: TextFirstV1EntryPoint) -> Bool {
        switch entryPoint {
        case .textInput, .markdownTable:
            true
        case .audioRecording,
             .cameraCapture,
             .photoPicker,
             .documentFilePicker,
             .microphone,
             .ocr,
             .transcription,
             .attachment:
            false
        }
    }

    public static func allowsAttachmentRecordCreation(from _: TextFirstV1EntryPoint) -> Bool {
        false
    }

    public static func allowsRuntimeNoteBodyMutation(from entryPoint: TextFirstV1EntryPoint) -> Bool {
        switch entryPoint {
        case .textInput, .markdownTable:
            true
        case .audioRecording,
             .cameraCapture,
             .photoPicker,
             .documentFilePicker,
             .microphone,
             .ocr,
             .transcription,
             .attachment:
            false
        }
    }

    public static func runtimeEntryPoint(for appEntryPoint: TextFirstV1AppEntryPoint) -> TextFirstV1EntryPoint {
        switch appEntryPoint {
        case .noteTextInput:
            .textInput
        case .noteMarkdownTable:
            .markdownTable
        case .noteStartRecording, .noteStopRecording:
            .audioRecording
        case .noteAddImage, .notePersistedAttachments, .chatAttachment:
            .attachment
        case .noteAddFile:
            .documentFilePicker
        case .noteCameraCapture:
            .cameraCapture
        case .notePhotoPicker:
            .photoPicker
        case .noteMicrophone, .chatMicrophone:
            .microphone
        }
    }

    public static func isEnabled(_ appEntryPoint: TextFirstV1AppEntryPoint) -> Bool {
        isEnabled(runtimeEntryPoint(for: appEntryPoint))
    }

    public static func allowsAttachmentRecordCreation(from appEntryPoint: TextFirstV1AppEntryPoint) -> Bool {
        allowsAttachmentRecordCreation(from: runtimeEntryPoint(for: appEntryPoint))
    }

    public static func allowsRuntimeNoteBodyMutation(from appEntryPoint: TextFirstV1AppEntryPoint) -> Bool {
        allowsRuntimeNoteBodyMutation(from: runtimeEntryPoint(for: appEntryPoint))
    }

    public static func shouldRestoreArchivedPresentationState(
        archivedPresentationText: String,
        runtimeBody: String
    ) -> Bool {
        guard !archivedPresentationText.contains("\u{FFFC}") else { return false }
        return archivedPresentationText == runtimeBody
    }
}
