//
//  TrashView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 15/06/26.
//

import SwiftUI

struct TrashView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = TrashViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                headerBar
                content
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            vm.load()
        }
        .alert("Permanently delete all notes in Trash?", isPresented: $vm.showEmptyConfirm) {
            Button("Delete All", role: .destructive) {
                vm.emptyAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Permanently delete this note?", isPresented: Binding(
            get: { vm.deleteTarget != nil },
            set: { if !$0 { vm.deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let note = vm.deleteTarget {
                    vm.permanentlyDelete(note)
                }
                vm.deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { vm.deleteTarget = nil }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
            }
            Text("Trash")
                .font(.custom("HelveticaNeue-Bold", size: 16))
                .foregroundStyle(Color.labelPrimary)
            Spacer()
            Button("Empty") {
                vm.showEmptyConfirm = true
            }
            .font(.custom("HelveticaNeue", size: 14))
            .foregroundStyle(vm.trashed.isEmpty ? Color.labelSecondary : Color.red)
            .disabled(vm.trashed.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if vm.trashed.isEmpty {
            Spacer()
            Text("Trash is empty")
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(Color.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        } else {
            List {
                ForEach(vm.trashed) { note in
                    trashCard(note)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                vm.deleteTarget = note
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                vm.restore(note)
                            } label: {
                                Label("Recover", systemImage: "arrow.uturn.left")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
    }

    private func trashCard(_ note: Note) -> some View {
        HStack(spacing: 14) {
            NoteIcon(type: note.type)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.custom("HelveticaNeue-Bold", size: 15))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(vm.subtitleText(for: note))
                    .font(.custom("HelveticaNeue", size: 12))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
}

#Preview {
    NavigationStack {
        TrashView()
    }
}
