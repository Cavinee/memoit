import Foundation

// A synchronous request/response bridge for the production embedded host.
// Distinct from LocalQVACAdapterTransport (which is the dev/Mac transport).
public protocol ProductionEmbeddedQVACHostBridge: Sendable {
    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse]
}

public enum ProductionEmbeddedQVACHostAdapterError: Error, Equatable, Sendable, CustomStringConvertible {
    case requestFailed(requestID: QVACAdapterRequestID, code: String, message: String)
    case canceled(requestID: QVACAdapterRequestID)
    case missingCompletion(requestID: QVACAdapterRequestID)
    case unexpectedCompletion(requestID: QVACAdapterRequestID)

    public var description: String {
        switch self {
        case .requestFailed(let requestID, let code, let message):
            return "Production embedded QVAC host adapter request \(requestID) failed with \(code): \(message)"
        case .canceled(let requestID):
            return "Production embedded QVAC host adapter request \(requestID) was canceled"
        case .missingCompletion(let requestID):
            return "Production embedded QVAC host adapter request \(requestID) ended without completion"
        case .unexpectedCompletion(let requestID):
            return "Production embedded QVAC host adapter request \(requestID) returned an unexpected completion payload"
        }
    }
}

public struct ProductionEmbeddedQVACHostAdapter: AIRuntimeAdapter {
    private let bridge: any ProductionEmbeddedQVACHostBridge
    private let requestIDProvider: () -> QVACAdapterRequestID

    public init(
        bridge: any ProductionEmbeddedQVACHostBridge,
        requestIDProvider: @escaping () -> QVACAdapterRequestID = { QVACAdapterRequestID(UUID().uuidString) }
    ) {
        self.bridge = bridge
        self.requestIDProvider = requestIDProvider
    }

    public func modelAvailability() throws -> AIRuntimeModelAvailability {
        let requestID = requestIDProvider()
        let request = QVACAdapterRequest(id: requestID, operation: .modelAvailability)
        let responses = try bridge.send(request)
        var availability: QVACAdapterModelAvailability?

        for response in responses where response.requestID == requestID {
            switch response.event {
            case .modelAvailability(let payload):
                availability = payload
            case .error(let payload):
                throw ProductionEmbeddedQVACHostAdapterError.requestFailed(
                    requestID: requestID,
                    code: payload.code,
                    message: payload.message
                )
            case .canceled:
                throw ProductionEmbeddedQVACHostAdapterError.canceled(requestID: requestID)
            case .progress, .token, .completed:
                continue
            }
        }

        guard let availability else {
            throw ProductionEmbeddedQVACHostAdapterError.missingCompletion(requestID: requestID)
        }

        return availability.runtimeAvailability
    }

    public func answer(prompt: String, mode: AnswerMode, context: [Note]) throws -> String {
        let result = try run(.answer(.init(
            prompt: prompt,
            mode: mode.adapterMode,
            context: context.map(\.adapterContext)
        )))
        return try result.text()
    }

    public func suggestedRelationships(for sourceNote: Note, in corpus: [Note]) throws -> [SuggestedRelationship] {
        let result = try run(.suggestRelationships(.init(
            sourceNote: sourceNote.adapterContext,
            corpus: corpus.map(\.adapterContext)
        )))

        guard case .relationships(let relationships) = result.completion else {
            throw ProductionEmbeddedQVACHostAdapterError.unexpectedCompletion(requestID: result.requestID)
        }

        return relationships.map { relationship in
            SuggestedRelationship(
                sourceNoteID: NoteID(relationship.sourceNoteID),
                targetNoteID: NoteID(relationship.targetNoteID),
                explanation: relationship.explanation,
                citations: relationship.citations.map {
                    SourceCitation(noteID: NoteID($0.noteID), noteFragmentID: $0.noteFragmentID)
                }
            )
        }
    }

    public func generatedNoteBodies(prompt: String, destinationCount: Int) throws -> AIWriteAdapterResult {
        do {
            let result = try run(.generateNoteBodies(.init(
                prompt: prompt,
                destinationCount: destinationCount
            )))

            guard case .noteBodies(let bodies) = result.completion else {
                throw ProductionEmbeddedQVACHostAdapterError.unexpectedCompletion(requestID: result.requestID)
            }

            return .completed(bodies)
        } catch ProductionEmbeddedQVACHostAdapterError.canceled {
            return .canceled
        }
    }

    public func summary(for notes: [Note], progress: (AIProgressState) -> Void) throws -> String {
        // Progress events are intentionally not surfaced to the caller in this slice.
        // Streaming/progress reporting is handled in a later issue.
        let result = try run(.summary(.init(notes: notes.map(\.adapterContext))))
        return try result.text()
    }

    private func run(_ operation: QVACAdapterOperation) throws -> AggregatedProductionEmbeddedResult {
        let requestID = requestIDProvider()
        let request = QVACAdapterRequest(id: requestID, operation: operation)
        let responses = try bridge.send(request)
        var tokens: [String] = []
        var completion: QVACAdapterCompletion?

        for response in responses where response.requestID == requestID {
            switch response.event {
            case .modelAvailability:
                continue
            case .progress:
                continue
            case .token(let token):
                tokens.append(token)
            case .completed(let completed):
                completion = completed
            case .canceled:
                throw ProductionEmbeddedQVACHostAdapterError.canceled(requestID: requestID)
            case .error(let payload):
                throw ProductionEmbeddedQVACHostAdapterError.requestFailed(
                    requestID: requestID,
                    code: payload.code,
                    message: payload.message
                )
            }
        }

        guard let completion else {
            throw ProductionEmbeddedQVACHostAdapterError.missingCompletion(requestID: requestID)
        }

        return AggregatedProductionEmbeddedResult(
            requestID: requestID,
            streamedText: tokens.joined(),
            completion: completion
        )
    }
}

private struct AggregatedProductionEmbeddedResult {
    let requestID: QVACAdapterRequestID
    let streamedText: String
    let completion: QVACAdapterCompletion

    func text() throws -> String {
        if !streamedText.isEmpty {
            return streamedText
        }

        guard case .text(let text) = completion else {
            throw ProductionEmbeddedQVACHostAdapterError.unexpectedCompletion(requestID: requestID)
        }

        return text
    }
}

private extension Note {
    var adapterContext: QVACAdapterNoteContext {
        QVACAdapterNoteContext(noteID: id.rawValue, title: title, body: body)
    }
}

private extension AnswerMode {
    var adapterMode: QVACAdapterAnswerMode {
        switch self {
        case .noteGrounded:
            return .noteGrounded
        case .general:
            return .general
        }
    }
}

private extension QVACAdapterModelAvailability {
    var runtimeAvailability: AIRuntimeModelAvailability {
        let downloadedProfiles = profiles
            .filter(\.isDownloaded)
            .map {
                LocalModelProfile(
                    id: LocalModelProfileID($0.id),
                    name: $0.name,
                    isDownloaded: $0.isDownloaded,
                    isRemovable: $0.isRemovable
                )
            }
        let downloadedProfileIDs = Set(downloadedProfiles.map(\.id))
        let runtimeDefaultProfileID = defaultProfileID
            .map(LocalModelProfileID.init)
            .flatMap { downloadedProfileIDs.contains($0) ? $0 : nil }

        return AIRuntimeModelAvailability(
            isAIReady: isAIReady && !downloadedProfiles.isEmpty,
            inventory: ModelInventory(
                downloadedProfiles: downloadedProfiles,
                defaultProfileID: runtimeDefaultProfileID
            )
        )
    }
}
