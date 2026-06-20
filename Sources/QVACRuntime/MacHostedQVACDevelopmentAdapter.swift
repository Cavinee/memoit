import Foundation

public protocol LocalQVACAdapterTransport {
    func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse]
}

public struct LocalProcessQVACAdapterTransport: LocalQVACAdapterTransport {
    private let commandPath: String?
    private let arguments: [String]
    private let responseTimeout: TimeInterval

    public init(commandPath: String? = nil, arguments: [String] = [], responseTimeout: TimeInterval = 30) {
        self.commandPath = commandPath
        self.arguments = arguments
        self.responseTimeout = responseTimeout
    }

    public func send(_ request: QVACAdapterRequest) throws -> [QVACAdapterResponse] {
        guard let commandPath, !commandPath.isEmpty else {
            throw QVACDevelopmentAdapterError.transportUnavailable("Mac-hosted QVAC adapter process is not configured")
        }

        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = arguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw QVACDevelopmentAdapterError.transportUnavailable("Failed to launch local QVAC adapter process '\(commandPath)': \(error)")
        }

        do {
            var requestData = try JSONEncoder().encode(request)
            requestData.append(0x0A)
            try stdin.fileHandleForWriting.write(contentsOf: requestData)
            try stdin.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw QVACDevelopmentAdapterError.transportUnavailable("Failed to write request \(request.id) to local QVAC adapter process '\(commandPath)': \(error)")
        }

        let collector = LocalProcessQVACAdapterResponseCollector(requestID: request.id, commandPath: commandPath)
        let completed = DispatchSemaphore(value: 0)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                completed.signal()
                return
            }
            if collector.appendStdout(data) {
                completed.signal()
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                collector.appendStderr(data)
            }
        }
        process.terminationHandler = { _ in
            stdout.fileHandleForReading.readabilityHandler = nil
            let remainingStdout = stdout.fileHandleForReading.readDataToEndOfFile()
            let reachedTerminalAfterDrain = !remainingStdout.isEmpty && collector.appendStdout(remainingStdout)
            stderr.fileHandleForReading.readabilityHandler = nil
            let remainingStderr = stderr.fileHandleForReading.readDataToEndOfFile()
            if !remainingStderr.isEmpty {
                collector.appendStderr(remainingStderr)
            }
            if reachedTerminalAfterDrain {
                completed.signal()
                return
            }
            completed.signal()
        }

        let waitResult = completed.wait(timeout: .now() + responseTimeout)
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil

        if waitResult == .timedOut {
            process.terminate()
            throw QVACDevelopmentAdapterError.transportUnavailable("Timed out waiting for local QVAC adapter response for request \(request.id)")
        }

        if collector.hasTerminalResponse, process.isRunning {
            process.terminate()
        }
        if !process.isRunning, process.terminationStatus != 0, !collector.hasTerminalResponse {
            let stderrSuffix = collector.stderrOutput.isEmpty ? "" : ": \(collector.stderrOutput)"
            throw QVACDevelopmentAdapterError.transportUnavailable("Local QVAC adapter process '\(commandPath)' exited with status \(process.terminationStatus)\(stderrSuffix)")
        }

        return try collector.responsesOrThrow()
        #else
        throw QVACDevelopmentAdapterError.transportUnavailable("Local QVAC adapter process transport is only available on macOS")
        #endif
    }
}

#if os(macOS)
private final class LocalProcessQVACAdapterResponseCollector: @unchecked Sendable {
    private let requestID: QVACAdapterRequestID
    private let commandPath: String
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()
    private var collectedResponses: [QVACAdapterResponse] = []
    private var terminalResponseReached = false
    private var decodeFailure: Error?

    init(requestID: QVACAdapterRequestID, commandPath: String) {
        self.requestID = requestID
        self.commandPath = commandPath
    }

    var hasTerminalResponse: Bool {
        lock.withLock { terminalResponseReached }
    }

    var stderrOutput: String {
        lock.withLock {
            String(data: stderrBuffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    func appendStdout(_ data: Data) -> Bool {
        lock.withLock {
            stdoutBuffer.append(data)
            while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A), !terminalResponseReached {
                let line = stdoutBuffer[..<newlineIndex]
                stdoutBuffer.removeSubrange(...newlineIndex)
                processLine(Data(line))
            }
            return terminalResponseReached || decodeFailure != nil
        }
    }

    func appendStderr(_ data: Data) {
        lock.withLock {
            stderrBuffer.append(data)
        }
    }

    func responsesOrThrow() throws -> [QVACAdapterResponse] {
        try lock.withLock {
            if let decodeFailure {
                throw decodeFailure
            }
            return collectedResponses
        }
    }

    private func processLine(_ line: Data) {
        guard !line.isEmpty else { return }
        do {
            let response = try decoder.decode(QVACAdapterResponse.self, from: line)
            guard response.requestID == requestID else {
                return
            }
            collectedResponses.append(response)
            terminalResponseReached = response.event.isTerminal
        } catch {
            decodeFailure = QVACDevelopmentAdapterError.transportUnavailable("Failed to decode local QVAC adapter response for request \(requestID): \(error)")
        }
    }
}
#endif

public enum QVACDevelopmentAdapterError: Error, Equatable, Sendable, CustomStringConvertible {
    case transportUnavailable(String)
    case requestFailed(requestID: QVACAdapterRequestID, code: String, message: String)
    case canceled(requestID: QVACAdapterRequestID)
    case missingCompletion(requestID: QVACAdapterRequestID)
    case unexpectedCompletion(requestID: QVACAdapterRequestID)

    public var description: String {
        switch self {
        case .transportUnavailable(let message):
            return message
        case .requestFailed(let requestID, let code, let message):
            return "QVAC adapter request \(requestID) failed with \(code): \(message)"
        case .canceled(let requestID):
            return "QVAC adapter request \(requestID) was canceled"
        case .missingCompletion(let requestID):
            return "QVAC adapter request \(requestID) ended without completion"
        case .unexpectedCompletion(let requestID):
            return "QVAC adapter request \(requestID) returned an unexpected completion payload"
        }
    }
}

public enum QVACDevelopmentAdapterSmokeResult: Equatable, Sendable {
    case skipped(String)
    case configured(commandPath: String, modelPath: String)
}

public enum QVACDevelopmentAdapterSmoke {
    public static func evaluate(environment: [String: String] = ProcessInfo.processInfo.environment) -> QVACDevelopmentAdapterSmokeResult {
        guard let commandPath = environment["QVAC_DEV_ADAPTER_COMMAND"], !commandPath.isEmpty else {
            return .skipped("QVAC_DEV_ADAPTER_COMMAND is not configured")
        }
        guard let modelPath = environment["QVAC_DEV_MODEL_PATH"], !modelPath.isEmpty else {
            return .skipped("QVAC_DEV_MODEL_PATH is not configured")
        }

        return .configured(commandPath: commandPath, modelPath: modelPath)
    }
}

@available(*, deprecated, renamed: "AIRuntimeModelAvailability")
public typealias QVACDevelopmentModelAvailability = AIRuntimeModelAvailability

public struct MacHostedQVACDevelopmentAdapter: AIRuntimeAdapter {
    private let transport: any LocalQVACAdapterTransport
    private let requestIDProvider: () -> QVACAdapterRequestID

    public init(
        transport: any LocalQVACAdapterTransport = LocalProcessQVACAdapterTransport(),
        requestIDProvider: @escaping () -> QVACAdapterRequestID = { QVACAdapterRequestID(UUID().uuidString) }
    ) {
        self.transport = transport
        self.requestIDProvider = requestIDProvider
    }

    public func modelAvailability() throws -> AIRuntimeModelAvailability {
        let requestID = requestIDProvider()
        let request = QVACAdapterRequest(id: requestID, operation: .modelAvailability)
        let responses = try transport.send(request)
        var availability: QVACAdapterModelAvailability?

        for response in responses where response.requestID == requestID {
            switch response.event {
            case .modelAvailability(let payload):
                availability = payload
            case .error(let payload):
                throw QVACDevelopmentAdapterError.requestFailed(
                    requestID: requestID,
                    code: payload.code,
                    message: payload.message
                )
            case .canceled:
                throw QVACDevelopmentAdapterError.canceled(requestID: requestID)
            case .progress, .token, .completed:
                continue
            }
        }

        guard let availability else {
            throw QVACDevelopmentAdapterError.missingCompletion(requestID: requestID)
        }

        return availability.runtimeAvailability
    }

    public func cancel(requestID targetRequestID: QVACAdapterRequestID) throws {
        let request = QVACAdapterRequest(id: requestIDProvider(), operation: .cancel(targetRequestID))
        _ = try transport.send(request)
    }

    public func suggestedRelationships(for sourceNote: Note, in corpus: [Note]) throws -> [SuggestedRelationship] {
        let result = try run(.suggestRelationships(.init(
            sourceNote: sourceNote.adapterContext,
            corpus: corpus.map(\.adapterContext)
        ))) { _, _ in }

        guard case .relationships(let relationships) = result.completion else {
            throw QVACDevelopmentAdapterError.unexpectedCompletion(requestID: result.requestID)
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

    public func answer(prompt: String, mode: AnswerMode, context: [Note]) throws -> String {
        let result = try run(.answer(.init(
            prompt: prompt,
            mode: mode.adapterMode,
            context: context.map(\.adapterContext)
        ))) { _, _ in }

        return try result.text()
    }

    public func generatedNoteBodies(prompt: String, destinationCount: Int) throws -> AIWriteAdapterResult {
        do {
            let result = try run(.generateNoteBodies(.init(
                prompt: prompt,
                destinationCount: destinationCount
            ))) { _, _ in }

            guard case .noteBodies(let bodies) = result.completion else {
                throw QVACDevelopmentAdapterError.unexpectedCompletion(requestID: result.requestID)
            }

            return .completed(bodies)
        } catch QVACDevelopmentAdapterError.canceled {
            return .canceled
        }
    }

    public func summary(for notes: [Note], progress: (AIProgressState) -> Void) throws -> String {
        let result = try run(.summary(.init(notes: notes.map(\.adapterContext)))) { state, _ in
            progress(state)
        }

        return try result.text()
    }

    private func run(_ operation: QVACAdapterOperation, progress: (AIProgressState, QVACAdapterRequestID) -> Void) throws -> AggregatedQVACAdapterResult {
        let requestID = requestIDProvider()
        let request = QVACAdapterRequest(id: requestID, operation: operation)
        let responses = try transport.send(request)
        var tokens: [String] = []
        var completion: QVACAdapterCompletion?

        for response in responses where response.requestID == requestID {
            switch response.event {
            case .modelAvailability:
                continue
            case .progress(let state):
                progress(state, requestID)
            case .token(let token):
                tokens.append(token)
            case .completed(let completed):
                completion = completed
            case .canceled:
                throw QVACDevelopmentAdapterError.canceled(requestID: requestID)
            case .error(let payload):
                throw QVACDevelopmentAdapterError.requestFailed(
                    requestID: requestID,
                    code: payload.code,
                    message: payload.message
                )
            }
        }

        guard let completion else {
            throw QVACDevelopmentAdapterError.missingCompletion(requestID: requestID)
        }

        return AggregatedQVACAdapterResult(
            requestID: requestID,
            streamedText: tokens.joined(),
            completion: completion
        )
    }
}

private struct AggregatedQVACAdapterResult {
    let requestID: QVACAdapterRequestID
    let streamedText: String
    let completion: QVACAdapterCompletion

    func text() throws -> String {
        if !streamedText.isEmpty {
            return streamedText
        }

        guard case .text(let text) = completion else {
            throw QVACDevelopmentAdapterError.unexpectedCompletion(requestID: requestID)
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

private extension QVACAdapterEvent {
    var isTerminal: Bool {
        switch self {
        case .completed, .canceled, .error:
            return true
        case .modelAvailability, .progress, .token:
            return false
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
