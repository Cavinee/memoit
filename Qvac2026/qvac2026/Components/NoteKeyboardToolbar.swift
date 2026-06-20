//
//  NoteKeyboardToolbar.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI

struct NoteKeyboardToolbar: View {
    @ObservedObject var state: NoteEditorViewModel

    var body: some View {
        modeContent
            .frame(height: 48)
            .background(Color.cardBackground)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -1)
    }

    @ViewBuilder
    private var modeContent: some View {
        switch state.activeToolbar {
        case .main:       mainBar
        case .formatting: formattingBar
        case .list:       listBar
        case .recording:  mainBar
        case .table:      tableBar
        }
    }

    // MARK: - Main Bar

    private var mainBar: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    // v1 text-first disabled entry points:
                    // icon("microphone") { state.startRecording() }
                    // icon("camera")     { state.showCameraPicker = true }
                    // icon("photo")      { state.showPhotoPicker = true }
                    // icon("paperclip")  { state.showFilePicker = true }
                    icon("link")                 { state.showNoteLinkPicker = true }
                    icon("textformat.alt")       { state.activeToolbar = .formatting }
                    icon("list.bullet")          { state.activeToolbar = .list }
                    icon("tablecells")           { state.insertTable() }
                    icon("arrow.uturn.backward") { state.editor.undo() }
                    icon("arrow.uturn.forward")  { state.editor.redo() }
                }
                .frame(height: 48)
                .padding(.horizontal, 16)
            }
            LinearGradient(
                colors: [Color.cardBackground.opacity(0), Color.cardBackground.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 63)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Formatting Bar

    private var formattingBar: some View {
        HStack(spacing: 0) {
            Button { state.activeToolbar = .main } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            Spacer()
            Button("Body") { state.editor.applyBody() }
                .font(.custom("HelveticaNeue-Bold", size: 14))
                .foregroundStyle(.primary)
            Spacer()
            Button("H1") { state.editor.applyHeading(1) }
                .font(.custom("HelveticaNeue-Bold", size: 14))
                .foregroundStyle(.primary)
            Spacer()
            Button("H2") { state.editor.applyHeading(2) }
                .font(.custom("HelveticaNeue-Bold", size: 14))
                .foregroundStyle(.primary)
            Spacer()
            Button("H3") { state.editor.applyHeading(3) }
                .font(.custom("HelveticaNeue-Bold", size: 14))
                .foregroundStyle(.primary)
            Spacer()
            icon("bold")            { state.editor.toggleBold() }
            Spacer()
            icon("italic")          { state.editor.toggleItalic() }
            Spacer()
            icon("underline")       { state.editor.toggleUnderline() }
            Spacer()
            icon("strikethrough")   { state.editor.toggleStrikethrough() }
            Spacer()
            icon("decrease.indent") { state.editor.indentDecrease() }
            Spacer()
            icon("increase.indent") { state.editor.indentIncrease() }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - List Bar

    private var listBar: some View {
        HStack(spacing: 0) {
            Button { state.activeToolbar = .main } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            Spacer()
            icon("list.bullet") { state.editor.toggleBulletList() }
            Spacer()
            icon("checklist")   { state.editor.toggleChecklist() }
            Spacer()
            icon("list.number") { state.editor.toggleNumberedList() }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recording Bar

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Text(state.recordingTimeString)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(
                    Array([8, 14, 20, 12, 18, 22, 10, 16, 20, 8, 14, 18, 22, 12, 16, 10, 20, 14]
                        .enumerated()),
                    id: \.offset
                ) { _, h in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blueLight)
                        .frame(width: 3, height: CGFloat(h))
                }
            }

            Spacer()

            Button { state.cancelRecording() } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }

            Button { state.stopRecording() } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.bluePrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Table Bar

    private var tableBar: some View {
        let rowCount = state.focusedTable?.cells.count ?? 0
        let colCount = state.focusedTable?.cells.first?.count ?? 0
        return HStack(spacing: 0) {
            // Back to main toolbar
            Button { state.activeToolbar = .main } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            .padding(.leading, 16)

            Color.secondary.opacity(0.25)
                .frame(width: 1, height: 20)
                .padding(.horizontal, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Insert row above / below
                    icon("arrow.up.to.line")   { state.insertRowAbove() }
                    icon("arrow.down.to.line") { state.insertRowBelow() }

                    Color.secondary.opacity(0.25).frame(width: 1, height: 20)

                    // Insert column left / right
                    icon("arrow.left.to.line")  { state.insertColumnLeft()  }
                    icon("arrow.right.to.line") { state.insertColumnRight() }

                    Color.secondary.opacity(0.25).frame(width: 1, height: 20)

                    // Delete row (disabled at 1 row)
                    Button("Del Row") { state.deleteRow() }
                        .font(.custom("HelveticaNeue-Bold", size: 13))
                        .foregroundStyle(rowCount > 1 ? Color.red : Color.secondary)
                        .disabled(rowCount <= 1)

                    // Delete column (disabled at 1 column)
                    Button("Del Col") { state.deleteColumn() }
                        .font(.custom("HelveticaNeue-Bold", size: 13))
                        .foregroundStyle(colCount > 1 ? Color.red : Color.secondary)
                        .disabled(colCount <= 1)
                }
                .frame(height: 48)
                .padding(.trailing, 16)
            }
        }
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
    }
}
