//
//  NewNoteView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI
import Combine

struct NewNoteView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: NoteEditorViewModel

    @State private var autosaveCancellable: AnyCancellable?

    init(noteID: UUID = UUID()) {
        _vm = StateObject(wrappedValue: NoteEditorViewModel(blankWithId: noteID))
    }

    var body: some View {
        NoteEditorBody(state: vm, onMoveToTrash: trashAndDismiss)
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(vm.hasUnsavedChanges)
            .onAppear {
                vm.loadContent(note: nil)
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
                vm.persist()
            }
    }

    private func trashAndDismiss() {
        guard vm.persistIfChanged() else { return }
        vm.moveToTrash()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewNoteView()
    }
}
