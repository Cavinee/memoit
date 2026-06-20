import Foundation
import QVACRuntime

#if canImport(ExpoModulesCore)
import ExpoModulesCore
#endif

enum ProductionEmbeddedQVACHostRuntimeError: Error {
    case expoRuntimeUnavailable
}

final class ProductionEmbeddedQVACHostRuntime: @unchecked Sendable {
    static let shared = ProductionEmbeddedQVACHostRuntime()

    private init() {}

    func status(
        for request: ProductionIOSEmbeddedQVACHostStatusRequest
    ) async throws -> ProductionIOSEmbeddedQVACHostStatusResponse {
        #if canImport(ExpoModulesCore)
        return try await ProductionEmbeddedQVACHostStatusModule.sendStatusRequest(request)
        #else
        throw ProductionEmbeddedQVACHostRuntimeError.expoRuntimeUnavailable
        #endif
    }

    func startupStatus() async throws -> ProductionIOSEmbeddedQVACHostLinkedStartupStatus {
        #if canImport(ExpoModulesCore)
        let request = ProductionIOSEmbeddedQVACHostStatusRequest(
            id: .init(UUID().uuidString),
            hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
        )
        let response = try await ProductionEmbeddedQVACHostStatusModule.sendStatusRequest(request)

        switch response.status {
        case .ready:
            return .ready
        case .starting:
            return .starting
        case .notLinked, .unavailable:
            return .unavailable
        }
        #else
        throw ProductionEmbeddedQVACHostRuntimeError.expoRuntimeUnavailable
        #endif
    }
}
