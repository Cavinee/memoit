import Combine
import Foundation
import QVACRuntime

struct ViewModelBehaviorTestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ description: String) throws {
    if !condition() {
        throw ViewModelBehaviorTestFailure(description: description)
    }
}

@MainActor
final class KnowledgeRuntimeService {
    static let shared = KnowledgeRuntimeService()

    var stubbedAnswer: PresentationAnswer?
    var stubbedAnswerError: Error?

    func aiSessionHistory() -> [PresentationAISessionHistoryEntry] {
        []
    }

    func deleteAISessionHistoryEntry(id: AISessionHistoryEntryID) throws {}

    func answer(prompt: String, mode: AnswerMode = .noteGrounded) throws -> PresentationAnswer {
        if let stubbedAnswerError { throw stubbedAnswerError }
        return stubbedAnswer ?? PresentationAnswer(
            answer: "",
            mode: mode,
            modeLabel: testModeLabel(mode),
            isConstrainedToRetrievedNotes: mode == .noteGrounded,
            citations: []
        )
    }

    func answerAsync(prompt: String, mode: AnswerMode = .noteGrounded) async throws -> PresentationAnswer {
        try answer(prompt: prompt, mode: mode)
    }
}

func testModeLabel(_ mode: AnswerMode) -> String {
    switch mode {
    case .noteGrounded:
        "Note-grounded Answer"
    case .general:
        "General AI Answer"
    }
}

struct PresentationAnswer {
    let answer: String
    let mode: AnswerMode
    let modeLabel: String
    let isConstrainedToRetrievedNotes: Bool
    let citations: [PresentationSourceCitation]
}

@MainActor
final class FakeHistoryService {
    var entries: [PresentationAISessionHistoryEntry]
    var deletionError: Error?
    private(set) var deletedIDs: [AISessionHistoryEntryID] = []

    init(entries: [PresentationAISessionHistoryEntry]) {
        self.entries = entries
    }

    func aiSessionHistory() -> [PresentationAISessionHistoryEntry] {
        entries
    }

    func deleteAISessionHistoryEntry(id: AISessionHistoryEntryID) throws {
        if let deletionError {
            throw deletionError
        }
        deletedIDs.append(id)
        entries.removeAll { $0.id == id }
    }
}

@MainActor
func runChatHistoryViewModelBehaviorTests() throws {
    let createdAt = Date(timeIntervalSince1970: 1_830_000_400)
    let entry = PresentationAISessionHistoryEntry(
        entry: AISessionHistoryEntry(
            id: .init("ai-session-history-1"),
            prompt: "basalt texture",
            response: "Basalt is fine-grained.",
            mode: .noteGrounded,
            createdAt: createdAt,
            citations: [SourceCitation(noteID: .init("note-basalt"), noteFragmentID: "note-body")]
        )
    ) { noteID in
        noteID == NoteID("note-basalt") ? "Basalt field guide" : nil
    }
    let service = FakeHistoryService(entries: [entry])
    let viewModel = ChatHistoryViewModel(
        loadHistory: { service.aiSessionHistory() },
        deleteHistoryEntry: { try service.deleteAISessionHistoryEntry(id: $0) }
    )

    viewModel.load()

    try expect(viewModel.entries == [entry], "Chat History view model should load runtime AI Session History entries")

    viewModel.delete(entryID: entry.id)

    try expect(service.deletedIDs == [entry.id], "Chat History view model should delete through runtime history service")
    try expect(viewModel.entries.isEmpty, "Chat History view model should reload after deleting runtime history entry")
    try expect(viewModel.deletionErrorMessage == nil, "successful delete should not publish a delete error")

    service.entries = [entry]
    service.deletionError = ViewModelBehaviorTestFailure(description: "delete failed")
    viewModel.load()
    viewModel.delete(entryID: entry.id)

    try expect(viewModel.entries == [entry], "failed delete should leave loaded runtime history entries intact")
    try expect(
        viewModel.deletionErrorMessage == ChatHistoryDeletionPresentationState.failureMessage,
        "failed delete should publish the runtime presentation failure message"
    )
}

@MainActor
func runChatAIHistoryRestoreBehaviorTests() throws {
    let entry = PresentationAISessionHistoryEntry(
        entry: AISessionHistoryEntry(
            id: .init("ai-session-history-2"),
            prompt: "What does Testing link to?",
            response: "Testing links to Hello.",
            mode: .noteGrounded,
            createdAt: Date(timeIntervalSince1970: 1_830_000_800),
            citations: [SourceCitation(noteID: .init("note-hello"), noteFragmentID: "note-body")]
        )
    ) { noteID in
        noteID == NoteID("note-hello") ? "Hello" : nil
    }

    let viewModel = ChatAIViewModel()
    viewModel.restoreHistory(entry)

    try expect(viewModel.messages.count == 2, "restored Chat History entry should render the saved prompt and response")
    try expect(viewModel.messages[0].role == .user, "restored first message should be the saved user prompt")
    try expect(viewModel.messages[0].text == entry.prompt, "restored first message should use the saved prompt text")
    try expect(viewModel.messages[1].role == .assistant, "restored second message should be the saved assistant response")
    try expect(viewModel.messages[1].text == entry.response, "restored second message should use the saved response text")
    try expect(viewModel.messages[1].modeLabel == entry.modeLabel, "restored assistant response should preserve the saved answer mode")
    try expect(viewModel.citations == entry.citations, "restored Chat History entry should restore saved Source Citations")
    try expect(viewModel.inputText.isEmpty, "restoring Chat History should not leave stale draft input")
    try expect(!viewModel.isLoading, "restoring Chat History should leave ChatAI idle")
}

@MainActor
func runChatAIAsyncAnswerBehaviorTests() async throws {
    // Arrange: configure stub service with a canned answer
    let service = KnowledgeRuntimeService()
    let expectedAnswer = PresentationAnswer(
        answer: "Basalt is fine-grained igneous rock.",
        mode: .noteGrounded,
        modeLabel: testModeLabel(.noteGrounded),
        isConstrainedToRetrievedNotes: true,
        citations: []
    )
    service.stubbedAnswer = expectedAnswer
    let viewModel = ChatAIViewModel(runtimeService: service)

    // Act: send a prompt and wait for the async answer task to complete
    viewModel.inputText = "What is basalt?"
    viewModel.send()

    // Yield enough times to let the inner Task run and complete
    for _ in 0..<10 { await Task.yield() }

    // Assert: assistant message appended, isLoading cleared
    try expect(viewModel.messages.count == 2, "async answer should append user + assistant messages")
    try expect(viewModel.messages[1].role == .assistant, "second message should be the assistant's answer")
    try expect(viewModel.messages[1].text == expectedAnswer.answer, "assistant message should contain the answer text")
    try expect(!viewModel.isLoading, "isLoading should be false after async answer completes")

    // Assert: error path — stub an error, reset state, verify isLoading cleared and error shown
    service.stubbedAnswer = nil
    service.stubbedAnswerError = ViewModelBehaviorTestFailure(description: "model unavailable")
    viewModel.inputText = "What is granite?"
    viewModel.send()
    for _ in 0..<10 { await Task.yield() }
    try expect(!viewModel.isLoading, "isLoading should be false after async answer error")
}

try await MainActor.run {
    try runChatHistoryViewModelBehaviorTests()
    try runChatAIHistoryRestoreBehaviorTests()
}
try await runChatAIAsyncAnswerBehaviorTests()
