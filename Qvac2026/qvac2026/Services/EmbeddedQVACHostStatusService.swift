import Foundation
import QVACRuntime

final class EmbeddedQVACHostStatusService {
    static let shared = EmbeddedQVACHostStatusService(bridge: defaultBridge())

    private let bridge: any ProductionIOSEmbeddedQVACHostStatusBridge
    private let requestIDProvider: () -> ProductionIOSEmbeddedQVACHostRequestID

    private static func defaultBridge() -> any ProductionIOSEmbeddedQVACHostStatusBridge {
        #if canImport(ExpoModulesCore)
        return ProductionIOSEmbeddedQVACHostLinkedStatusBridge(
            statusResponseProvider: { request in
                do {
                    return try await ProductionEmbeddedQVACHostRuntime.shared.status(for: request)
                } catch {
                    print(
                        "EmbeddedQVACHostStatusService startup status provider failed requestID=\(request.id.rawValue) diagnosticCode=embedded-qvac-host-provider-failed"
                    )
                    throw error
                }
            }
        )
        #else
        return ProductionIOSEmbeddedQVACHostNotLinkedStatusBridge()
        #endif
    }

    init(
        bridge: any ProductionIOSEmbeddedQVACHostStatusBridge = ProductionIOSEmbeddedQVACHostNotLinkedStatusBridge(),
        requestIDProvider: @escaping () -> ProductionIOSEmbeddedQVACHostRequestID = {
            ProductionIOSEmbeddedQVACHostRequestID(UUID().uuidString)
        }
    ) {
        self.bridge = bridge
        self.requestIDProvider = requestIDProvider
    }

    func startStartupProbe() {
        let requestID = requestIDProvider()
        let request = ProductionIOSEmbeddedQVACHostStatusRequest(
            id: requestID,
            hostKind: .physicalIOSEmbeddedExpoBehindAIRuntimeAdapter
        )
        let bridge = bridge

        Task {
            do {
                let response = try await ProductionIOSEmbeddedQVACHost.status(for: request, using: bridge)
                print(
                    "EmbeddedQVACHostStatusService startup status requestID=\(response.requestID.rawValue) hostKind=\(response.hostKind.rawValue) status=\(response.status.rawValue) diagnosticCode=\(response.diagnosticCode)"
                )
            } catch {
                print("EmbeddedQVACHostStatusService startup status failed requestID=\(requestID.rawValue)")
            }
        }
    }
}
