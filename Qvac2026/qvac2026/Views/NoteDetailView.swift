//
//  NoteDetailView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI
import Combine

struct NoteDetailView: View {

    let note: Note

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: NoteEditorViewModel

    @State private var autosaveCancellable: AnyCancellable?

    init(note: Note) {
        self.note = note
        _vm = StateObject(wrappedValue: NoteEditorViewModel(note: note))
    }

    var body: some View {
        NoteEditorBody(state: vm, onMoveToTrash: trashAndDismiss)
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(vm.hasUnsavedChanges)
            .onAppear {
                vm.loadContent(note: note)
                autosaveCancellable = vm.editor.$attributedText
                    .dropFirst()
                    .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
                    .sink { _ in
                        vm.markChanged()
                        vm.persist()
                    }
            }
            .onChange(of: vm.noteTitle) { _, _ in
                vm.markChanged()
                vm.persist()
            }
            .onDisappear {
                vm.editor.textView?.resignFirstResponder()
                vm.editor.isFocused = false
                vm.activeToolbar = .main
                vm.persistIfChanged()
            }
    }

    private func trashAndDismiss() {
        guard vm.persistIfChanged() else { return }
        vm.moveToTrash()
        dismiss()
    }
}

#Preview("Existing Note") {
    NavigationStack {
        NoteDetailView(note: Note.samples[0])
    }
}
