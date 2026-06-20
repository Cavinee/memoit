public struct QVACAdapterRequestID: Hashable, Equatable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct QVACAdapterRequest: Equatable, Codable, Sendable {
    public let id: QVACAdapterRequestID
    public let operation: QVACAdapterOperation

    public init(id: QVACAdapterRequestID, operation: QVACAdapterOperation) {
        self.id = id
        self.operation = operation
    }
}

public enum QVACAdapterOperation: Equatable, Codable, Sendable {
    case modelAvailability
    case answer(QVACAdapterAnswerRequest)
    case summary(QVACAdapterSummaryRequest)
    case generateNoteBodies(QVACAdapterGenerateNoteBodiesRequest)
    case suggestRelationships(QVACAdapterRelationshipRequest)
    case cancel(QVACAdapterRequestID)
}

public enum QVACAdapterAnswerMode: String, Equatable, Codable, Sendable {
    case noteGrounded = "note-grounded"
    case general
}

public struct QVACAdapterNoteContext: Equatable, Codable, Sendable {
    public let noteID: String
    public let title: String
    public let body: String

    public init(noteID: String, title: String, body: String) {
        self.noteID = noteID
        self.title = title
        self.body = body
    }
}

public struct QVACAdapterAnswerRequest: Equatable, Codable, Sendable {
    public let prompt: String
    public let mode: QVACAdapterAnswerMode
    public let context: [QVACAdapterNoteContext]

    public init(prompt: String, mode: QVACAdapterAnswerMode, context: [QVACAdapterNoteContext]) {
        self.prompt = prompt
        self.mode = mode
        self.context = context
    }
}

public struct QVACAdapterSummaryRequest: Equatable, Codable, Sendable {
    public let notes: [QVACAdapterNoteContext]

    public init(notes: [QVACAdapterNoteContext]) {
        self.notes = notes
    }
}

public struct QVACAdapterGenerateNoteBodiesRequest: Equatable, Codable, Sendable {
    public let prompt: String
    public let destinationCount: Int

    public init(prompt: String, destinationCount: Int) {
        self.prompt = prompt
        self.destinationCount = destinationCount
    }
}

public struct QVACAdapterRelationshipRequest: Equatable, Codable, Sendable {
    public let sourceNote: QVACAdapterNoteContext
    public let corpus: [QVACAdapterNoteContext]

    public init(sourceNote: QVACAdapterNoteContext, corpus: [QVACAdapterNoteContext]) {
        self.sourceNote = sourceNote
        self.corpus = corpus
    }
}

public struct QVACAdapterResponse: Equatable, Codable, Sendable {
    public let requestID: QVACAdapterRequestID
    public let event: QVACAdapterEvent

    public init(requestID: QVACAdapterRequestID, event: QVACAdapterEvent) {
        self.requestID = requestID
        self.event = event
    }
}

public enum QVACAdapterEvent: Equatable, Codable, Sendable {
    case modelAvailability(QVACAdapterModelAvailability)
    case progress(AIProgressState)
    case token(String)
    case completed(QVACAdapterCompletion)
    case canceled
    case error(QVACAdapterErrorPayload)
}

public enum QVACAdapterCompletion: Equatable, Codable, Sendable {
    case text(String)
    case noteBodies([String])
    case relationships([QVACAdapterSuggestedRelationship])
}

public struct QVACAdapterModelAvailability: Equatable, Codable, Sendable {
    public let isAIReady: Bool
    public let profiles: [QVACAdapterModelProfile]
    public let defaultProfileID: String?

    public init(isAIReady: Bool, profiles: [QVACAdapterModelProfile], defaultProfileID: String?) {
        self.isAIReady = isAIReady
        self.profiles = profiles
        self.defaultProfileID = defaultProfileID
    }
}

public struct QVACAdapterModelProfile: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let isDownloaded: Bool
    public let isRemovable: Bool

    public init(id: String, name: String, isDownloaded: Bool, isRemovable: Bool) {
        self.id = id
        self.name = name
        self.isDownloaded = isDownloaded
        self.isRemovable = isRemovable
    }
}

public struct QVACAdapterSuggestedRelationship: Equatable, Codable, Sendable {
    public let sourceNoteID: String
    public let targetNoteID: String
    public let explanation: String
    public let citations: [QVACAdapterSourceCitation]

    public init(sourceNoteID: String, targetNoteID: String, explanation: String, citations: [QVACAdapterSourceCitation]) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.explanation = explanation
        self.citations = citations
    }
}

public struct QVACAdapterSourceCitation: Equatable, Codable, Sendable {
    public let noteID: String
    public let noteFragmentID: String

    public init(noteID: String, noteFragmentID: String) {
        self.noteID = noteID
        self.noteFragmentID = noteFragmentID
    }
}

public struct QVACAdapterErrorPayload: Equatable, Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ProductionIOSQVACAdapterContract: Equatable, Codable, Sendable {
    public let hostKind: ProductionIOSQVACAdapterHostKind
    public let macHostedDevelopmentAdapterRole: MacHostedQVACDevelopmentAdapterRole
    public let payloadAuthority: QVACBridgePayloadAuthority
    public let bridgeEvents: [ProductionIOSQVACBridgeEvent]
    public let forbiddenResponsibilities: [ProductionIOSQVACForbiddenResponsibility]
    public let forbiddenDependencies: [ProductionIOSQVACForbiddenDependency]
    public let lifecycleRisks: [ProductionIOSQVACLifecycleRisk]
    public let validationRequirement: ProductionIOSQVACValidationRequirement
    public let executionLocality: ProductionIOSQVACExecutionLocality
    public let contextScope: ProductionIOSQVACContextScope
    public let citationAuthority: ProductionIOSQVACCitationAuthority

    public init(
        hostKind: ProductionIOSQVACAdapterHostKind,
        macHostedDevelopmentAdapterRole: MacHostedQVACDevelopmentAdapterRole,
        payloadAuthority: QVACBridgePayloadAuthority,
        bridgeEvents: [ProductionIOSQVACBridgeEvent],
        forbiddenResponsibilities: [ProductionIOSQVACForbiddenResponsibility],
        forbiddenDependencies: [ProductionIOSQVACForbiddenDependency],
        lifecycleRisks: [ProductionIOSQVACLifecycleRisk],
        validationRequirement: ProductionIOSQVACValidationRequirement,
        executionLocality: ProductionIOSQVACExecutionLocality,
        contextScope: ProductionIOSQVACContextScope,
        citationAuthority: ProductionIOSQVACCitationAuthority
    ) {
        self.hostKind = hostKind
        self.macHostedDevelopmentAdapterRole = macHostedDevelopmentAdapterRole
        self.payloadAuthority = payloadAuthority
        self.bridgeEvents = bridgeEvents
        self.forbiddenResponsibilities = forbiddenResponsibilities
        self.forbiddenDependencies = forbiddenDependencies
        self.lifecycleRisks = lifecycleRisks
        self.validationRequirement = validationRequirement
        self.executionLocality = executionLocality
        self.contextScope = contextScope
        self.citationAuthority = citationAuthority
    }

    public static let embeddedExpoBehindAIRuntimeAdapter = ProductionIOSQVACAdapterContract(
        hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter,
        macHostedDevelopmentAdapterRole: .developmentOnlyDistinctFromProduction,
        payloadAuthority: .swiftRequestScopedPromptContextAndModel,
        bridgeEvents: [.progress, .token, .completion, .cancel, .error],
        forbiddenResponsibilities: [
            .reactNativeOrExpoUI,
            .notePersistence,
            .graphTraversal,
            .citationAuthority,
            .wholeCorpusNoteAccess
        ],
        forbiddenDependencies: [
            .cloudBackendOrInference,
            .hostedExpoService,
            .nodeSidecar,
            .emulatorOnlyAssumption
        ],
        lifecycleRisks: [
            .hostLifecycle,
            .requestCancellation,
            .localModelFileOwnership,
            .memoryPressure,
            .appBackgrounding
        ],
        validationRequirement: .physicalIOSDeviceRequired,
        executionLocality: .bundledLocalOnDevice,
        contextScope: .swiftSelectedContextOnly,
        citationAuthority: .swiftRuntime
    )
}

public enum ProductionIOSQVACAdapterHostKind: String, Equatable, Codable, Sendable {
    case physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
}

public enum MacHostedQVACDevelopmentAdapterRole: String, Equatable, Codable, Sendable {
    case developmentOnlyDistinctFromProduction
}

public enum QVACBridgePayloadAuthority: String, Equatable, Codable, Sendable {
    case swiftRequestScopedPromptContextAndModel
}

public enum ProductionIOSQVACBridgeEvent: String, Equatable, Codable, Sendable {
    case progress
    case token
    case completion
    case cancel
    case error
}

public enum ProductionIOSQVACForbiddenResponsibility: String, Equatable, Codable, Sendable {
    case reactNativeOrExpoUI
    case notePersistence
    case graphTraversal
    case citationAuthority
    case wholeCorpusNoteAccess
}

public enum ProductionIOSQVACForbiddenDependency: String, Equatable, Codable, Sendable {
    case cloudBackendOrInference
    case hostedExpoService
    case nodeSidecar
    case emulatorOnlyAssumption
}

public enum ProductionIOSQVACLifecycleRisk: String, Equatable, Codable, Sendable {
    case hostLifecycle
    case requestCancellation
    case localModelFileOwnership
    case memoryPressure
    case appBackgrounding
}

public enum ProductionIOSQVACValidationRequirement: String, Equatable, Codable, Sendable {
    case physicalIOSDeviceRequired
}

public enum ProductionIOSQVACExecutionLocality: String, Equatable, Codable, Sendable {
    case bundledLocalOnDevice
}

public enum ProductionIOSQVACContextScope: String, Equatable, Codable, Sendable {
    case swiftSelectedContextOnly
}

public enum ProductionIOSQVACCitationAuthority: String, Equatable, Codable, Sendable {
    case swiftRuntime
}
