import Foundation

public enum AnswerFallbackPolicy {
    public static func requiresGeneralFallbackConfirmation(after error: Error, attemptedMode: AnswerMode) -> Bool {
        guard attemptedMode == .noteGrounded else {
            return false
        }
        guard let runtimeError = error as? RuntimeError else {
            return false
        }
        return runtimeError == .noRetrievedContext(.noteGrounded)
    }
}

public struct PresentationSourceCitation: Equatable, Sendable {
    public let noteID: String
    public let noteTitle: String?
    public let noteFragmentID: String

    public init(citation: SourceCitation, noteTitle: String?) {
        self.noteID = citation.noteID.rawValue
        self.noteTitle = noteTitle
        self.noteFragmentID = citation.noteFragmentID
    }

    public var displayTitle: String {
        noteTitle ?? noteID
    }
}

public struct PresentationAISessionHistoryEntry: Equatable, Identifiable, Sendable {
    public let id: AISessionHistoryEntryID
    public let prompt: String
    public let response: String
    public let mode: AnswerMode
    public let modeLabel: String
    public let createdAt: Date
    public let citations: [PresentationSourceCitation]

    public init(
        entry: AISessionHistoryEntry,
        noteTitle: (NoteID) throws -> String?
    ) rethrows {
        id = entry.id
        prompt = entry.prompt
        response = entry.response
        mode = entry.mode
        modeLabel = entry.mode.label
        createdAt = entry.createdAt
        citations = try entry.citations.map { citation in
            PresentationSourceCitation(
                citation: citation,
                noteTitle: try noteTitle(citation.noteID)
            )
        }
    }
}

public struct ChatHistoryDeletionPresentationState: Equatable, Sendable {
    public static let failureMessage = "This chat history entry could not be deleted."

    public var errorMessage: String?

    public init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }

    public mutating func didDeleteSuccessfully() {
        errorMessage = nil
    }

    public mutating func didFailToDelete() {
        errorMessage = Self.failureMessage
    }
}

public struct ChatAnswerRequestGuard: Equatable, Sendable {
    public private(set) var activeRequestID: String?
    public private(set) var cancelledRequestIDs: Set<String>

    public init(activeRequestID: String? = nil, cancelledRequestIDs: Set<String> = []) {
        self.activeRequestID = activeRequestID
        self.cancelledRequestIDs = cancelledRequestIDs
    }

    public mutating func begin(requestID: String) {
        activeRequestID = requestID
        cancelledRequestIDs.remove(requestID)
    }

    public mutating func cancelActive() {
        guard let activeRequestID else {
            return
        }
        cancelledRequestIDs.insert(activeRequestID)
        self.activeRequestID = nil
    }

    public mutating func finish(requestID: String) {
        if activeRequestID == requestID {
            activeRequestID = nil
        }
        cancelledRequestIDs.remove(requestID)
    }

    public func canApplyResult(for requestID: String) -> Bool {
        activeRequestID == requestID && !cancelledRequestIDs.contains(requestID)
    }
}

public struct ChatAnswerPresentationState: Equatable, Sendable {
    public var citations: [PresentationSourceCitation]
    public var errorMessage: String?

    public init(citations: [PresentationSourceCitation] = [], errorMessage: String? = nil) {
        self.citations = citations
        self.errorMessage = errorMessage
    }

    public mutating func prepareForNewAnswer() {
        citations = []
        errorMessage = nil
    }

    public mutating func clearAfterCancellation() {
        citations = []
        errorMessage = nil
    }
}

public enum DevelopmentModelProfilePolicy {
    public static let environmentVariable = "QVAC_ENABLE_DEBUG_FAKE_MODEL_PROFILE"
    public static let launchArgument = "-QVACEnableDebugFakeModelProfile"

    public static func isOptedIn(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = CommandLine.arguments
    ) -> Bool {
        environment[environmentVariable] == "1" || arguments.contains(launchArgument)
    }
}
