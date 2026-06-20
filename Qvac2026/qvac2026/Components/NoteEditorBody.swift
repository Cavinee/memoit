//
//  NoteEditorBody.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct NoteEditorBody: View {

    @ObservedObject var state: NoteEditorViewModel
    var onMoveToTrash: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            contentEditor
                            if state.isRecording {
                                listeningPill.padding(.top, 10)
                            }
                            // Tappable filler — routes taps on empty space below the last
                            // block to the text view, placing the caret at the end.
                            Color.clear
                                .frame(minHeight: 140, maxHeight: .infinity)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { state.editor.focusAtEnd() }
                        }
                        .padding(.horizontal, 20)
                        // Ensures short notes fill the viewport so the filler expands
                        // to cover all empty space; long notes scroll normally.
                        .frame(minHeight: geo.size.height, alignment: .top)
                    }
                    // Inline "/" and "@" command surfaces float over the editor,
                    // between the header and the keyboard toolbar.
                    .overlay { commandMenuOverlay }
                }
            }

            // v1 text-first: the floating audio/camera/photo/file attachment bar is disabled.
            // if !state.editor.isFocused {
            //     floatingBar.padding(.bottom, 28)
            // }
        }
        .alert("Rename Note", isPresented: $state.showRename) {
            TextField("Title", text: $state.renameText)
            Button("Save") { state.applyManualRename(state.renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Save Failed", isPresented: $state.showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.saveErrorMessage)
        }
        // v1 text-first: photo picker and camera capture entry points are disabled.
        // .photosPicker(isPresented: $state.showPhotoPicker, selection: $state.selectedPhotos, matching: .images)
        // .onChange(of: state.selectedPhotos) { _, items in
        //     Task { @MainActor in
        //         for item in items {
        //             if let data = try? await item.loadTransferable(type: Data.self),
        //                let img = UIImage(data: data) {
        //                 state.addImage(img)
        //             }
        //         }
        //         state.selectedPhotos = []
        //     }
        // }
        // .fullScreenCover(isPresented: $state.showCameraPicker) {
        //     CameraPicker { img in state.addImage(img) }
        //         .ignoresSafeArea()
        // }
        .fullScreenCover(item: $state.presentedImage) { item in
            ImageViewerView(image: item.image)
        }
        .sheet(item: $state.presentedFile) { file in
            FilePreviewView(url: file.url)
        }
        // v1 text-first: document/file picker entry point is disabled.
        // .fileImporter(isPresented: $state.showFilePicker, allowedContentTypes: [.data]) { result in
        //     guard let url = try? result.get() else { return }
        //     let scoped = url.startAccessingSecurityScopedResource()
        //     defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        //     state.addFile(from: url)
        // }
    }

    // MARK: - Header

    private var isCommandMenuActive: Bool {
        state.showSlashMenu || state.showNoteLinkPicker
    }

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                if state.persistIfChanged() {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
            }

            if isCommandMenuActive {
                // Editing a command: the title collapses to a "@ ▾" / "/ ▾" mode
                // chip. Tapping it (or the dimmed area behind the card) dismisses.
                commandModeChip
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.noteTitle)
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .foregroundStyle(.primary)
                    Text(state.formattedDate)
                        .font(.custom("HelveticaNeue", size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if state.editor.isFocused {
                    Button {
                        // Resign whichever UIResponder is currently active —
                        // works for both the main text view and table cell fields.
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                    }
                } else {
                    Menu {
                        Button { } label: { Label("Share", systemImage: "square.and.arrow.up") }
                        Button { state.renameText = state.noteTitle; state.showRename = true } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            onMoveToTrash()
                        } label: { Label("Move to Trash", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .rotationEffect(.degrees(90))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
    }

    private var commandModeChip: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { state.dismissCommandMenus() }
        } label: {
            HStack(spacing: 5) {
                Text(state.showSlashMenu ? "/" : "@")
                    .font(.custom("HelveticaNeue-Bold", size: 20))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Editor

    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            if state.editor.isEmpty {
                Text("Type [ / ] to insert formatting and [ @ ] to link a note")
                    .font(.custom("HelveticaNeue", size: 15))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .allowsHitTesting(false)
            }
            RichTextEditor(controller: state.editor) {
                NoteKeyboardToolbar(state: state)
            }
            .frame(minHeight: 200)
            .onAppear {
                state.editor.onMentionTrigger = {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        state.showSlashMenu = false
                        state.showNoteLinkPicker = true
                    }
                }
                state.editor.onSlashTrigger = {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        state.showNoteLinkPicker = false
                        state.showSlashMenu = true
                    }
                }
            }
            .onDisappear {
                state.editor.onMentionTrigger = nil
                state.editor.onSlashTrigger = nil
            }
        }
    }

    @ViewBuilder
    private var commandMenuOverlay: some View {
        if state.showSlashMenu {
            SlashCommandMenu(state: state)
        } else if state.showNoteLinkPicker {
            MentionCommandMenu(state: state)
        }
    }

    // MARK: - Listening Pill

    private var listeningPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("Listening ...")
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Floating Bar (keyboard not visible)

    private var floatingBar: some View {
        EmptyView()
        // v1 text-first disabled entry points:
        // HStack(spacing: 24) {
        //     icon("mic")                { state.editor.textView?.becomeFirstResponder(); state.startRecording() }
        //     icon("camera")             { state.showCameraPicker = true }
        //     icon("photo.on.rectangle") { state.showPhotoPicker = true }
        //     icon("paperclip")          { state.showFilePicker  = true }
        // }
        // .padding(.horizontal, 20)
        // .padding(.vertical, 14)
        // .fixedSize()
        // .background(Color.white)
        // .clipShape(Capsule())
        // .overlay(Capsule().stroke(Color(hex: "#DCDCDC"), lineWidth: 1))
        // .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func icon(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }
}
