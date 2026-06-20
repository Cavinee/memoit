import Foundation
import QVACRuntime

#if canImport(ExpoModulesCore)
import ExpoModulesCore
#endif

enum ProductionEmbeddedQVACHostAnswerResponderError: Error {
    case bareHostBridgeUnavailable
    case invalidRequest
    case invalidResponse
    case timeout
    case answerFailed(code: String, message: String)
}

final class ProductionEmbeddedQVACHostAnswerResponder: @unchecked Sendable {
    // Model load + generation can take well over a minute on first run.
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64 = 600_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func sendAnswerRequest(
        requestID: String,
        prompt: String,
        mode: String,
        context: [[String: String]]
    ) async throws -> String {
        guard !requestID.isEmpty else {
            throw ProductionEmbeddedQVACHostAnswerResponderError.invalidRequest
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.sendAnswerRequestWithoutTimeout(
                    requestID: requestID,
                    prompt: prompt,
                    mode: mode,
                    context: context
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: self.timeoutNanoseconds)
                throw ProductionEmbeddedQVACHostAnswerResponderError.timeout
            }

            guard let result = try await group.next() else {
                throw ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse
            }
            group.cancelAll()
            return result
        }
    }

    private func sendAnswerRequestWithoutTimeout(
        requestID: String,
        prompt: String,
        mode: String,
        context: [[String: String]]
    ) async throws -> String {
        let requestPayload = ProductionEmbeddedQVACHostAnswerRequestPayload(
            requestID: requestID,
            prompt: prompt,
            mode: mode,
            context: context.map {
                ProductionEmbeddedQVACHostAnswerContextEntry(
                    noteID: $0["noteID"] ?? "",
                    title: $0["title"] ?? "",
                    body: $0["body"] ?? ""
                )
            }
        )
        let requestData = try JSONEncoder().encode(requestPayload)
        let responseData = try await ProductionEmbeddedQVACBareHostAnswerClient.sendAnswerRequestData(requestData)
        let responsePayload = try JSONDecoder().decode(
            ProductionEmbeddedQVACHostAnswerResponsePayload.self,
            from: responseData
        )

        guard responsePayload.protocolValue == ProductionEmbeddedQVACHostAnswerRequestPayload.protocolName,
              responsePayload.type == "qvac.host.answer.response",
              responsePayload.requestID == requestID else {
            throw ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse
        }

        switch responsePayload.status {
        case "completed":
            guard let text = responsePayload.text else {
                throw ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse
            }
            return text
        case "error":
            throw ProductionEmbeddedQVACHostAnswerResponderError.answerFailed(
                code: responsePayload.errorCode ?? "unknown",
                message: responsePayload.errorMessage ?? "Unknown error"
            )
        default:
            throw ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse
        }
    }

    private enum ProductionEmbeddedQVACBareHostAnswerClient {
        static func sendAnswerRequestData(_ requestData: Data) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                ProductionEmbeddedQVACBareHostBridge.sendAnswerRequest(requestData) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data else {
                        continuation.resume(throwing: ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse)
                        return
                    }
                    continuation.resume(returning: data as Data)
                }
            }
        }
    }
}

// MARK: - Wire protocol types

private struct ProductionEmbeddedQVACHostAnswerRequestPayload: Codable {
    static let protocolName = "qvac.embeddedHost.answer.v1"

    let protocolValue: String
    let type: String
    let requestID: String
    let prompt: String
    let mode: String
    let context: [ProductionEmbeddedQVACHostAnswerContextEntry]

    init(
        requestID: String,
        prompt: String,
        mode: String,
        context: [ProductionEmbeddedQVACHostAnswerContextEntry]
    ) {
        self.protocolValue = Self.protocolName
        self.type = "qvac.host.answer"
        self.requestID = requestID
        self.prompt = prompt
        self.mode = mode
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case protocolValue = "protocol"
        case type
        case requestID
        case prompt
        case mode
        case context
    }
}

private struct ProductionEmbeddedQVACHostAnswerContextEntry: Codable {
    let noteID: String
    let title: String
    let body: String
}

private struct ProductionEmbeddedQVACHostAnswerResponsePayload: Codable {
    let protocolValue: String
    let type: String
    let requestID: String?
    let status: String
    let text: String?
    let errorCode: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case protocolValue = "protocol"
        case type
        case requestID
        case status
        case text
        case errorCode
        case errorMessage
    }
}

// MARK: - Module façade

final class ProductionEmbeddedQVACHostAnswerModule {
    private static let responder = ProductionEmbeddedQVACHostAnswerResponder()

    static func sendAnswerRequest(
        requestID: String,
        prompt: String,
        mode: String,
        context: [[String: String]]
    ) async throws -> String {
        try await responder.sendAnswerRequest(
            requestID: requestID,
            prompt: prompt,
            mode: mode,
            context: context
        )
    }
}
