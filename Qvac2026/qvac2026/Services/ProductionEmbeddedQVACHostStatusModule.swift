import Foundation
import QVACRuntime

#if canImport(ExpoModulesCore)
import ExpoModulesCore
#endif

enum ProductionEmbeddedQVACHostStatusResponderError: Error {
    case bareHostBridgeUnavailable
    case invalidRequest
    case invalidResponse
    case timeout
}

final class ProductionEmbeddedQVACHostStatusResponder: @unchecked Sendable {
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64 = 2_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func sendStatusRequest(
        _ request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        guard !request.id.rawValue.isEmpty else {
            throw ProductionEmbeddedQVACHostStatusResponderError.invalidRequest
        }

        return try await withThrowingTaskGroup(
            of: ProductionIOSEmbeddedQVACHostStatusResponse.self
        ) { group in
            group.addTask {
                try await self.sendStatusRequestWithoutTimeout(request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: self.timeoutNanoseconds)
                throw ProductionEmbeddedQVACHostStatusResponderError.timeout
            }

            guard let response = try await group.next() else {
                throw ProductionEmbeddedQVACHostStatusResponderError.invalidResponse
            }
            group.cancelAll()
            return response
        }
    }

    private func sendStatusRequestWithoutTimeout(
        _ request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        let requestPayload = ProductionEmbeddedQVACHostStatusRequestPayload(
            requestID: request.id.rawValue
        )
        let requestData = try JSONEncoder().encode(requestPayload)
        let responseData = try await ProductionEmbeddedQVACBareHostStatusClient.sendStatusRequestData(requestData)
        let responsePayload = try JSONDecoder().decode(
            ProductionEmbeddedQVACHostStatusResponsePayload.self,
            from: responseData
        )

        guard responsePayload.protocolValue == ProductionEmbeddedQVACHostStatusRequestPayload.protocolName,
              responsePayload.type == "qvac.host.status.response",
              let responseRequestID = responsePayload.requestID else {
            throw ProductionEmbeddedQVACHostStatusResponderError.invalidResponse
        }

        let status: ProductionIOSEmbeddedQVACHostStatus
        let diagnostic: ProductionIOSEmbeddedQVACHostDiagnostic
        switch responsePayload.status {
        case "ready":
            status = .ready
            diagnostic = .embeddedHostReady
        case "starting":
            status = .starting
            diagnostic = .embeddedHostStarting
        case "unavailable":
            status = .unavailable
            diagnostic = .embeddedHostUnavailable
        default:
            throw ProductionEmbeddedQVACHostStatusResponderError.invalidResponse
        }

        return ProductionIOSEmbeddedQVACHostStatusResponse(
            requestID: .init(responseRequestID),
            hostKind: request.hostKind,
            status: status,
            diagnostic: diagnostic,
            lifecycleRisks: ProductionIOSQVACAdapterContract.embeddedExpoBehindAIRuntimeAdapter.lifecycleRisks
        )
    }

    private enum ProductionEmbeddedQVACBareHostStatusClient {
        static func sendStatusRequestData(_ requestData: Data) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                ProductionEmbeddedQVACBareHostBridge.sendStatusRequest(requestData) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data else {
                        continuation.resume(throwing: ProductionEmbeddedQVACHostStatusResponderError.invalidResponse)
                        return
                    }
                    continuation.resume(returning: data as Data)
                }
            }
        }
    }

}

private struct ProductionEmbeddedQVACHostStatusRequestPayload: Codable {
    static let protocolName = "qvac.embeddedHost.status.v1"

    let protocolValue: String
    let type: String
    let requestID: String

    init(requestID: String) {
        self.protocolValue = Self.protocolName
        self.type = "qvac.host.status"
        self.requestID = requestID
    }

    enum CodingKeys: String, CodingKey {
        case protocolValue = "protocol"
        case type
        case requestID
    }
}

private struct ProductionEmbeddedQVACHostStatusResponsePayload: Codable {
    let protocolValue: String
    let type: String
    let requestID: String?
    let status: String
    let diagnostic: String?
    let runtime: String?

    enum CodingKeys: String, CodingKey {
        case protocolValue = "protocol"
        case type
        case requestID
        case status
        case diagnostic
        case runtime
    }
}

final class ProductionEmbeddedQVACHostStatusModule {
    private static let responder = ProductionEmbeddedQVACHostStatusResponder()

    static func sendStatusRequest(
        _ request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        try await responder.sendStatusRequest(request)
    }
}

#if canImport(ExpoModulesCore)
final class ProductionEmbeddedQVACHostStatusExpoModule: Module {
    func definition() -> ModuleDefinition {
        Name("ProductionEmbeddedQVACHostStatus")

        AsyncFunction("statusAsync") { (requestID: String) async throws -> [String: String] in
            let request = ProductionIOSEmbeddedQVACHostStatusRequest(
                id: .init(requestID),
                hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
            )
            let response = try await ProductionEmbeddedQVACHostStatusModule.sendStatusRequest(request)
            return [
                "requestID": response.requestID.rawValue,
                "status": response.status.rawValue,
                "diagnosticCode": response.diagnosticCode
            ]
        }
    }
}
#endif
