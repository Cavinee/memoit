//
//  RelatedNotesSheet.swift
//  qvac2026
//
//  Presents the notes the on-device embedding index ranked as most related to a
//  selected note. Ranking is pure cosine similarity over already-computed note
//  embeddings — it never touches the answer/generation worklet or the .qvac model path.
//

import SwiftUI

struct RelatedNotesSheet: View {
    let result: RelatedNotesResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if result.related.isEmpty {
                    emptyState
                } else {
                    relatedList
                }
            }
            .background(AppBackground())
            .navigationTitle("Related Notes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: NoteRoute.self) { route in
                switch route {
                case .new(let id):
                    NewNoteView(noteID: id)
                        .id(route.destinationID)
                case .existing(let note):
                    NoteDetailView(note: note)
                        .id(route.destinationID)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var relatedList: some View {
        List {
            Section {
                ForEach(result.related) { note in
                    ZStack {
                        NavigationLink(value: NoteRoute.existing(note)) { EmptyView() }
                            .opacity(0)
                        NoteCard(note: note)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Related to \"\(result.sourceTitle)\"")
                    .font(.custom("HelveticaNeue", size: 13))
                    .foregroundStyle(Color.secondary)
                    .textCase(nil)
                    .padding(.leading, 20)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.secondary)
            Text("No related notes found")
                .font(.custom("HelveticaNeue-Bold", size: 16))
                .foregroundStyle(Color.primary)
            Text("Related notes appear here once \"\(result.sourceTitle)\" has enough in common with your other notes.")
                .font(.custom("HelveticaNeue", size: 13))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
