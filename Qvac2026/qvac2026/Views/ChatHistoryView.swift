//
//  ChatHistoryView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI
import QVACRuntime

struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ChatHistoryViewModel()
    let onSelect: (PresentationAISessionHistoryEntry) -> Void

    init(onSelect: @escaping (PresentationAISessionHistoryEntry) -> Void = { _ in }) {
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Nav bar
                HStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.trailing, 10)

                    Text("Chat History")
                        .font(.custom("HelveticaNeue-Medium", size: 16))
                        .foregroundStyle(Color.labelPrimary)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 10)

                if vm.entries.isEmpty {
                    Spacer()
                    Text("No chat history yet")
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundStyle(Color.labelTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    // Section label
                    Text("RECENT")
                        .font(.custom("HelveticaNeue-Medium", size: 14))
                        .foregroundStyle(Color.labelSecondary)
                        .kerning(1.0)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(vm.entries) { entry in
                                ChatHistoryRow(
                                    entry: entry,
                                    open: {
                                        onSelect(entry)
                                        dismiss()
                                    },
                                    delete: {
                                        vm.delete(entryID: entry.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            vm.load()
        }
        .alert(
            "Delete failed",
            isPresented: Binding(
                get: { vm.deletionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        vm.deletionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.deletionErrorMessage ?? "")
        }
    }
}

struct ChatHistoryRow: View {
    let entry: PresentationAISessionHistoryEntry
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                rowContent
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.prompt)
                    .font(.custom("HelveticaNeue-Medium", size: 14))
                    .foregroundStyle(Color.labelPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(entry.modeLabel)
                    Text("-")
                    Text(entry.createdAt, style: .date)
                    Text(entry.createdAt, style: .time)
                }
                .font(.custom("HelveticaNeue", size: 12))
                .foregroundStyle(Color.labelSecondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.response)
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(Color.labelPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.citations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(entry.citations.enumerated()), id: \.offset) { _, citation in
                        Text(citation.displayTitle)
                            .font(.custom("HelveticaNeue", size: 12))
                            .foregroundStyle(Color.labelSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ChatHistoryView()
    }
}
