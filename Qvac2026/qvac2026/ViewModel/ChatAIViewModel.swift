//
//  ChatAIViewModel.swift
//  qvac2026
//
//  Created by Codex on 18/06/26.
//

import Foundation
import Combine
import QVACRuntime

struct ChatAITranscriptMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let modeLabel: String?
}

@MainActor
final class ChatAIViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published private(set) var messages: [ChatAITranscriptMessage] = []
    @Published private(set) var presentationState = ChatAnswerPresentationState()
    @Published private(set) var isLoading = false
    @Published var needsGeneralFallbackConfirmation = false

    private let runtimeService: KnowledgeRuntimeService
    private var answerTask: Task<Void, Never>?
    private var requestGuard = ChatAnswerRequestGuard()
    private var requestSequence = 0
    private var pendingGeneralFallbackPrompt: String?

    init(runtimeService: KnowledgeRuntimeService? = nil) {
        self.runtimeService = runtimeService ?? .shared
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var citations: [PresentationSourceCitation] {
        presentationState.citations
    }

    var errorMessage: String? {
        presentationState.errorMessage
    }

    func send() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isLoading else {
            return
        }

        inputText = ""
        startAnswer(prompt: prompt, mode: .noteGrounded, appendPrompt: true)
    }

    func sendSuggestion(_ suggestion: String) {
        guard !isLoading else {
            return
        }

        inputText = suggestion
        send()
    }

    func confirmGeneralFallback() {
        guard let prompt = pendingGeneralFallbackPrompt else {
            needsGeneralFallbackConfirmation = false
            return
        }

        pendingGeneralFallbackPrompt = nil
        needsGeneralFallbackConfirmation = false
        startAnswer(prompt: prompt, mode: .general, appendPrompt: false)
    }

    func declineGeneralFallback() {
        pendingGeneralFallbackPrompt = nil
        needsGeneralFallbackConfirmation = false
        updatePresentationState { $0.clearAfterCancellation() }
    }

    func cancelAnswer() {
        answerTask?.cancel()
        answerTask = nil
        requestGuard.cancelActive()
        updatePresentationState { $0.clearAfterCancellation() }
        isLoading = false
    }

    func restoreHistory(_ entry: PresentationAISessionHistoryEntry) {
        answerTask?.cancel()
        answerTask = nil
        requestGuard.cancelActive()
        pendingGeneralFallbackPrompt = nil
        needsGeneralFallbackConfirmation = false
        inputText = ""
        isLoading = false
        messages = [
            ChatAITranscriptMessage(
                role: .user,
                text: entry.prompt,
                modeLabel: nil
            ),
            ChatAITranscriptMessage(
                role: .assistant,
                text: entry.response,
                modeLabel: entry.modeLabel
            )
        ]
        presentationState = ChatAnswerPresentationState(citations: entry.citations)
    }

    private func startAnswer(prompt: String, mode: AnswerMode, appendPrompt: Bool) {
        answerTask?.cancel()
        requestGuard.cancelActive()
        requestSequence += 1

        let requestID = "chat-answer-\(requestSequence)"
        requestGuard.begin(requestID: requestID)
        isLoading = true
        updatePresentationState { $0.prepareForNewAnswer() }
        if appendPrompt {
            messages.append(ChatAITranscriptMessage(
                role: .user,
                text: prompt,
                modeLabel: nil
            ))
        }

        answerTask = Task { [weak self] in
            await Task.yield()
            guard let self else {
                return
            }

            do {
                let result = try await runtimeService.answerAsync(prompt: prompt, mode: mode)
                guard requestGuard.canApplyResult(for: requestID) else {
                    return
                }

                messages.append(ChatAITranscriptMessage(
                    role: .assistant,
                    text: result.answer,
                    modeLabel: result.modeLabel
                ))
                updatePresentationState { $0.citations = result.citations }
                requestGuard.finish(requestID: requestID)
                isLoading = false
            } catch {
                guard requestGuard.canApplyResult(for: requestID) else {
                    return
                }

                requestGuard.finish(requestID: requestID)
                isLoading = false
                if AnswerFallbackPolicy.requiresGeneralFallbackConfirmation(after: error, attemptedMode: mode) {
                    pendingGeneralFallbackPrompt = prompt
                    needsGeneralFallbackConfirmation = true
                } else {
                    updatePresentationState { $0.errorMessage = String(describing: error) }
                }
            }
        }
    }

    private func updatePresentationState(_ update: (inout ChatAnswerPresentationState) -> Void) {
        var nextState = presentationState
        update(&nextState)
        presentationState = nextState
    }
}
