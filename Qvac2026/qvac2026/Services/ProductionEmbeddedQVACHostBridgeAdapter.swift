import Foundation
import QVACRuntime

// Bridges the synchronous ProductionEmbeddedQVACHostBridge to the async BareKit
// answer responder with a DispatchSemaphore. Streaming and cancellation come later
// (issue 18). `send` must run off the main thread — see the warning in sendAnswer.
final class ProductionEmbeddedQVACHostBridgeAdapter: ProductionEmbeddedQVACHostBridge {

    private static let bundledProfileID = "LLAMA_3_2_1B_INST_Q4_0"
    private static let bundledProfileName = "Llama 3.2 1B Instruct Q4_0"

    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] {
        switch request.operation {
        case .answer(let answerRequest):
            return try sendAnswer(request: request, answerRequest: answerRequest)

        case .modelAvailability:
            return modelAvailabilityResponses(requestID: request.id)

        case .summary, .generateNoteBodies, .suggestRelationships, .cancel:
            // Only answers go through the embedded host today; the rest land in issue 18.
            return [QVACAdapterResponse(
                requestID: request.id,
                event: .error(QVACAdapterErrorPayload(
                    code: "unsupported-in-embedded-host-slice-16b",
                    message: "Operation \(operationName(request.operation)) is not supported by the embedded host bridge in this release slice. See issue 18."
                ))
            )]
        }
    }

    // MARK: - Answer

    private func sendAnswer(
        request: QVACAdapterRequest,
        answerRequest: QVACAdapterAnswerRequest
    ) throws -> [QVACAdapterResponse] {
        let semaphore = DispatchSemaphore(value: 0)
        var resultText: String?
        var resultError: Error?

        let context: [[String: String]] = answerRequest.context.map {
            ["noteID": $0.noteID, "title": $0.title, "body": $0.body]
        }
        let modeString = answerRequest.mode.rawValue

        // Blocks until the async responder replies, so never call this on the main
        // thread — the BareKit reply is delivered on the main queue and would deadlock.
        Task {
            do {
                let text = try await ProductionEmbeddedQVACHostAnswerModule.sendAnswerRequest(
                    requestID: request.id.rawValue,
                    prompt: answerRequest.prompt,
                    mode: modeString,
                    context: context
                )
                resultText = text
            } catch {
                resultError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = resultError {
            return [QVACAdapterResponse(
                requestID: request.id,
                event: .error(mapAnswerError(error))
            )]
        }

        guard let text = resultText else {
            return [QVACAdapterResponse(
                requestID: request.id,
                event: .error(QVACAdapterErrorPayload(
                    code: "missing-answer-text",
                    message: "Answer response completed without text."
                ))
            )]
        }

        return [QVACAdapterResponse(
            requestID: request.id,
            event: .completed(.text(text))
        )]
    }

    // MARK: - Model availability

    private func modelAvailabilityResponses(requestID: QVACAdapterRequestID) -> [QVACAdapterResponse] {
        // Off-device builds have no embedded host, so report AI as unavailable.
        #if canImport(ExpoModulesCore)
        let isReady = synchronousStartupStatusIsReady()
        #else
        let isReady = false
        #endif

        let profile = QVACAdapterModelProfile(
            id: Self.bundledProfileID,
            name: Self.bundledProfileName,
            isDownloaded: isReady,
            isRemovable: false
        )

        return [QVACAdapterResponse(
            requestID: requestID,
            event: .modelAvailability(QVACAdapterModelAvailability(
                isAIReady: isReady,
                profiles: isReady ? [profile] : [],
                defaultProfileID: isReady ? Self.bundledProfileID : nil
            ))
        )]
    }

    #if canImport(ExpoModulesCore)
    private func synchronousStartupStatusIsReady() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var isReady = false

        Task {
            if let status = try? await ProductionEmbeddedQVACHostRuntime.shared.startupStatus() {
                isReady = (status == .ready)
            }
            semaphore.signal()
        }

        semaphore.wait()
        return isReady
    }
    #endif

    // MARK: - Helpers

    private func mapAnswerError(_ error: Error) -> QVACAdapterErrorPayload {
        switch error {
        case ProductionEmbeddedQVACHostAnswerResponderError.answerFailed(let code, let message):
            return QVACAdapterErrorPayload(code: code, message: message)
        case ProductionEmbeddedQVACHostAnswerResponderError.timeout:
            return QVACAdapterErrorPayload(
                code: "answer-timeout",
                message: "Answer request timed out waiting for embedded host response."
            )
        case ProductionEmbeddedQVACHostAnswerResponderError.invalidResponse:
            return QVACAdapterErrorPayload(
                code: "invalid-answer-response",
                message: "Embedded host returned an invalid or malformed answer response."
            )
        default:
            return QVACAdapterErrorPayload(
                code: "answer-bridge-error",
                message: error.localizedDescription
            )
        }
    }

    private func operationName(_ operation: QVACAdapterOperation) -> String {
        switch operation {
        case .modelAvailability: return "modelAvailability"
        case .answer: return "answer"
        case .summary: return "summary"
        case .generateNoteBodies: return "generateNoteBodies"
        case .suggestRelationships: return "suggestRelationships"
        case .cancel: return "cancel"
        }
    }
}
