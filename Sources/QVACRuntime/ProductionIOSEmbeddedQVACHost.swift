public struct ProductionIOSEmbeddedQVACHostRequestID: Hashable, Equatable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct ProductionIOSEmbeddedQVACHostStatusRequest: Equatable, Codable, Sendable {
    public let id: ProductionIOSEmbeddedQVACHostRequestID
    public let hostKind: ProductionIOSQVACAdapterHostKind

    public init(
        id: ProductionIOSEmbeddedQVACHostRequestID,
        hostKind: ProductionIOSQVACAdapterHostKind
    ) {
        self.id = id
        self.hostKind = hostKind
    }
}

public enum ProductionIOSEmbeddedQVACHostStatus: String, Equatable, Codable, Sendable {
    case notLinked
    case starting
    case ready
    case unavailable
}

public enum ProductionIOSEmbeddedQVACHostDiagnostic: String, Equatable, Codable, Sendable {
    case embeddedHostNotLinked = "embedded-qvac-host-not-linked"
    case embeddedHostStarting = "embedded-qvac-host-starting"
    case embeddedHostReady = "embedded-qvac-host-ready"
    case embeddedHostUnavailable = "embedded-qvac-host-unavailable"

    public var code: String {
        rawValue
    }

    public var message: String {
        switch self {
        case .embeddedHostNotLinked:
            return "Embedded QVAC host is not linked."
        case .embeddedHostStarting:
            return "Embedded QVAC host is starting."
        case .embeddedHostReady:
            return "Embedded QVAC host is ready."
        case .embeddedHostUnavailable:
            return "Embedded QVAC host is unavailable."
        }
    }
}

public struct ProductionIOSEmbeddedQVACHostStatusResponse: Equatable, Codable, Sendable {
    public let requestID: ProductionIOSEmbeddedQVACHostRequestID
    public let hostKind: ProductionIOSQVACAdapterHostKind
    public let status: ProductionIOSEmbeddedQVACHostStatus
    public let diagnostic: ProductionIOSEmbeddedQVACHostDiagnostic
    public let lifecycleRisks: [ProductionIOSQVACLifecycleRisk]

    public var diagnosticCode: String {
        diagnostic.code
    }

    public var diagnosticMessage: String {
        diagnostic.message
    }

    public init(
        requestID: ProductionIOSEmbeddedQVACHostRequestID,
        hostKind: ProductionIOSQVACAdapterHostKind,
        status: ProductionIOSEmbeddedQVACHostStatus,
        diagnostic: ProductionIOSEmbeddedQVACHostDiagnostic,
        lifecycleRisks: [ProductionIOSQVACLifecycleRisk]
    ) {
        self.requestID = requestID
        self.hostKind = hostKind
        self.status = status
        self.diagnostic = diagnostic
        self.lifecycleRisks = lifecycleRisks
    }
}

public protocol ProductionIOSEmbeddedQVACHostStatusBridge: Sendable {
    func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse
}

public enum ProductionIOSEmbeddedQVACHostLinkedStartupStatus: Equatable, Sendable {
    case starting
    case ready
    case unavailable
}

public struct ProductionIOSEmbeddedQVACHostLinkedStatusBridge: ProductionIOSEmbeddedQVACHostStatusBridge, Sendable {
    private enum Provider: Sendable {
        case startupStatus(@Sendable () async throws -> ProductionIOSEmbeddedQVACHostLinkedStartupStatus)
        case statusResponse(@Sendable (ProductionIOSEmbeddedQVACHostStatusRequest) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse)
    }

    private let provider: Provider

    public init(
        startupStatusProvider: @escaping @Sendable () async throws -> ProductionIOSEmbeddedQVACHostLinkedStartupStatus
    ) {
        self.provider = .startupStatus(startupStatusProvider)
    }

    public init(
        statusResponseProvider: @escaping @Sendable (ProductionIOSEmbeddedQVACHostStatusRequest) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse
    ) {
        self.provider = .statusResponse(statusResponseProvider)
    }

    public func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        switch provider {
        case .startupStatus(let startupStatusProvider):
            return try await statusFromStartupStatusProvider(startupStatusProvider, request: request)
        case .statusResponse(let statusResponseProvider):
            do {
                return try await statusResponseProvider(request)
            } catch {
                return unavailableResponse(for: request)
            }
        }
    }

    private func statusFromStartupStatusProvider(
        _ startupStatusProvider: @Sendable () async throws -> ProductionIOSEmbeddedQVACHostLinkedStartupStatus,
        request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        let startupStatus: ProductionIOSEmbeddedQVACHostLinkedStartupStatus
        do {
            startupStatus = try await startupStatusProvider()
        } catch {
            return unavailableResponse(for: request)
        }
        let status: ProductionIOSEmbeddedQVACHostStatus
        let diagnostic: ProductionIOSEmbeddedQVACHostDiagnostic

        switch startupStatus {
        case .starting:
            status = .starting
            diagnostic = .embeddedHostStarting
        case .ready:
            status = .ready
            diagnostic = .embeddedHostReady
        case .unavailable:
            status = .unavailable
            diagnostic = .embeddedHostUnavailable
        }

        return ProductionIOSEmbeddedQVACHostStatusResponse(
            requestID: request.id,
            hostKind: request.hostKind,
            status: status,
            diagnostic: diagnostic,
            lifecycleRisks: ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks
        )
    }

    private func unavailableResponse(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) -> ProductionIOSEmbeddedQVACHostStatusResponse {
        ProductionIOSEmbeddedQVACHostStatusResponse(
            requestID: request.id,
            hostKind: request.hostKind,
            status: .unavailable,
            diagnostic: .embeddedHostUnavailable,
            lifecycleRisks: ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks
        )
    }
}

public struct ProductionIOSEmbeddedQVACHostNotLinkedStatusBridge: ProductionIOSEmbeddedQVACHostStatusBridge, Sendable {
    public init() {}

    public func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        ProductionIOSEmbeddedQVACHostStatusResponse(
            requestID: request.id,
            hostKind: request.hostKind,
            status: .notLinked,
            diagnostic: .embeddedHostNotLinked,
            lifecycleRisks: ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks
        )
    }
}

public enum ProductionIOSEmbeddedQVACHostStatusBridgeError: Error, Equatable, Sendable, CustomStringConvertible {
    case unexpectedResponseRequestID(
        expected: ProductionIOSEmbeddedQVACHostRequestID,
        actual: ProductionIOSEmbeddedQVACHostRequestID
    )

    public var description: String {
        switch self {
        case .unexpectedResponseRequestID(let expected, let actual):
            return "Embedded QVAC host status response request ID mismatch: expected \(expected), got \(actual)"
        }
    }
}

public enum ProductionIOSEmbeddedQVACHost {
    public static func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest,
        using bridge: any ProductionIOSEmbeddedQVACHostStatusBridge
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        let response = try await bridge.status(for: request)
        guard response.requestID == request.id else {
            throw ProductionIOSEmbeddedQVACHostStatusBridgeError.unexpectedResponseRequestID(
                expected: request.id,
                actual: response.requestID
            )
        }
        return response
    }
}
