//
//  ChatAIView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI
import QVACRuntime

struct ChatAIView: View {
    @StateObject private var viewModel = ChatAIViewModel()
    
    private let suggestions = [
        "What is my to do list for 3 days ahead",
        "Give me and overview of my last 14 days",
        "Summarize my notes from the pas 3 days"
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Entropy AI")
                        .font(.custom("HelveticaNeue-Bold", size: 34))
                        .foregroundStyle(Color.primary)
                    
                    Spacer()
                    
                    NavigationLink(destination: ChatHistoryView { entry in
                        viewModel.restoreHistory(entry)
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                if viewModel.messages.isEmpty {
                    VStack(spacing: 12) {
                        Text("Ask about your note")
                            .font(.custom("HelveticaNeue-Medium", size: 20))
                            .foregroundStyle(Color.labelPrimary)
                            .padding(.bottom, 4)

                        ForEach(suggestions, id: \.self) { suggestion in
                            SuggestionPill(text: suggestion) {
                                viewModel.sendSuggestion(suggestion)
                            }
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubble(message: message)
                            }

                            if viewModel.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Generating")
                                        .font(.custom("HelveticaNeue-Medium", size: 13))
                                        .foregroundStyle(Color.labelSecondary)
                                    Spacer()
                                }
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.custom("HelveticaNeue", size: 13))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !viewModel.citations.isEmpty {
                                SourceCitationsView(citations: viewModel.citations)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
                
                Spacer()
                
                ChatInputBar(
                    text: $viewModel.inputText,
                    isLoading: viewModel.isLoading,
                    canSend: viewModel.canSend,
                    onSend: viewModel.send,
                    onCancel: viewModel.cancelAnswer
                )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .alert("No note context found", isPresented: $viewModel.needsGeneralFallbackConfirmation) {
            Button("Use General AI Answer") {
                viewModel.confirmGeneralFallback()
            }
            Button("Cancel", role: .cancel) {
                viewModel.declineGeneralFallback()
            }
        } message: {
            Text("No relevant Notes were retrieved. General AI Answer is not constrained to your Notes.")
        }
    }
}

struct SuggestionPill: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.custom("HelveticaNeue-Medium", size: 14))
                    .foregroundStyle(Color.blueMedium)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.blueMedium)
            }
            
        }
        .buttonStyle(.plain)
        .frame(width: 303, height: 40)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,                             
            y: 4
        )
    }
}

struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // v1 text-first: attachment/multimodal controls are disabled.
            if TextFirstV1AppGuard.canUseChatAttachment() {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 48)
                }
            }
            
            TextField("Ask Entropy anything", text: $text)
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .onSubmit(onSend)
            
            Spacer()
            
            if TextFirstV1AppGuard.canUseChatMicrophone() {
                Button(action: {}) {
                    Image(systemName: "microphone")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 48)
                }
            }

            Button(action: isLoading ? onCancel : onSend) {
                Image(systemName: isLoading ? "xmark" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill((canSend || isLoading) ? Color.blueMedium : Color.labelTertiary)
                    )
            }
            .disabled(!canSend && !isLoading)
            .padding(.trailing, 8)
        }
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("Colors/CardBackground"))
        )
    }
}

struct ChatMessageBubble: View {
    let message: ChatAITranscriptMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if let modeLabel = message.modeLabel {
                Text(modeLabel)
                    .font(.custom("HelveticaNeue-Medium", size: 11))
                    .foregroundStyle(Color.labelSecondary)
            }

            Text(message.text)
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(Color.labelPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(message.role == .user ? Color.blueLight : Color.cardBackground)
                )
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct SourceCitationsView: View {
    let citations: [PresentationSourceCitation]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source Citations")
                .font(.custom("HelveticaNeue-Bold", size: 13))
                .foregroundStyle(Color.labelPrimary)

            ForEach(Array(citations.enumerated()), id: \.offset) { _, citation in
                VStack(alignment: .leading, spacing: 2) {
                    Text(citation.displayTitle)
                        .font(.custom("HelveticaNeue-Medium", size: 13))
                        .foregroundStyle(Color.labelPrimary)
                    Text("\(citation.noteID) · \(citation.noteFragmentID)")
                        .font(.custom("HelveticaNeue", size: 11))
                        .foregroundStyle(Color.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cardBackground)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        ChatAIView()
    }
}

#Preview("Input Bar") {
    ChatInputBar(
        text: .constant(""),
        isLoading: false,
        canSend: false,
        onSend: {},
        onCancel: {}
    )
        .padding()
}
