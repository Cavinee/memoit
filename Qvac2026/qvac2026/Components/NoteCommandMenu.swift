//
//  NoteCommandMenu.swift
//  qvac2026
//
//  Inline command surfaces shown inside the note editor when the user types
//  `@` (mention a note) or `/` (insert formatting / date / attachment).
//
//  These replace the old full-screen `.sheet` note picker with a floating card
//  that sits between the editor header and the keyboard toolbar — matching the
//  design reference. Every colour is sourced from the adaptive asset-catalog
//  tokens so the surface is correct in both light and dark mode.
//

import SwiftUI

// MARK: - Shared chrome

/// Floating card chrome shared by the `@` and `/` menus: a dimmed tap-to-dismiss
/// scrim behind a rounded card that hosts the menu content. The card sits flush
/// under the editor header so it covers the note body cleanly — the active mode
/// is signalled by the "@ ⌄" / "/ ⌄" chip in the header, not by a floating glyph.
private struct CommandMenuCard<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            // Tap anywhere off the card to dismiss.
            Color.black.opacity(0.06)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 8)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)),
                removal: .opacity
            )
        )
    }
}

/// A small bold section label (e.g. "Mention a note", "Insert date").
private struct CommandSectionHeader: View {
    let title: String
    var topPadding: CGFloat = 0

    var body: some View {
        Text(title)
            .font(.custom("HelveticaNeue-Bold", size: 13))
            .foregroundStyle(Color.labelSecondary)
            .padding(.top, topPadding)
            .padding(.bottom, 8)
    }
}

/// A single tappable command row: leading glyph slot + title (+ optional subtitle).
private struct CommandRow: View {
    let leading: AnyView
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    init(leading: AnyView, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    /// Convenience for an SF Symbol leading glyph.
    init(symbol: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.init(
            leading: AnyView(
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.labelPrimary)
            ),
            title: title,
            subtitle: subtitle,
            action: action
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                    .frame(width: 26, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("HelveticaNeue", size: 16))
                        .foregroundStyle(Color.labelPrimary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundStyle(Color.labelSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - @ Mention menu

/// "Mention a note" — lists the user's active notes; tapping inserts a wikilink.
struct MentionCommandMenu: View {
    @ObservedObject var state: NoteEditorViewModel

    private var notes: [Note] { KnowledgeRuntimeService.shared.activeNotes() }

    var body: some View {
        CommandMenuCard(onDismiss: dismiss) {
            CommandSectionHeader(title: "Mention a note")

            if notes.isEmpty {
                Text("No notes yet")
                    .font(.custom("HelveticaNeue", size: 15))
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.vertical, 9)
            } else {
                ForEach(notes) { note in
                    CommandRow(
                        leading: AnyView(
                            Image(systemName: "doc.text")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(Color.labelSecondary)
                        ),
                        title: note.title,
                        subtitle: snippet(for: note)
                    ) {
                        perform { state.insertWikilink(to: note) }
                    }
                }
            }
        }
    }

    private func snippet(for note: Note) -> String {
        let trimmed = note.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No additional text" : trimmed
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.16)) { state.dismissCommandMenus() }
    }

    private func perform(_ work: () -> Void) {
        work()
        dismiss()
    }
}

// MARK: - / Slash menu

/// "/" — insert template / date / attachment / formatting, mirroring the reference.
struct SlashCommandMenu: View {
    @ObservedObject var state: NoteEditorViewModel

    var body: some View {
        CommandMenuCard(onDismiss: dismiss) {
            insertTemplateSection
            insertDateSection
            insertAttachmentSection
            insertFormattingSection
        }
    }

    // MARK: Insert template

    private var insertTemplateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommandSectionHeader(title: "Insert template")

            Button {
                // No template backend in v1 — dismiss gracefully. Shown for design parity.
                perform {}
            } label: {
                VStack(spacing: 6) {
                    Text("Often write the same types of notes over and over again?")
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundStyle(Color.labelPrimary)
                        .multilineTextAlignment(.center)
                    Text("Create a template")
                        .font(.custom("HelveticaNeue-Bold", size: 14))
                        .foregroundStyle(Color.bluePrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.iconBackground)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
    }

    // MARK: Insert date

    private var insertDateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommandSectionHeader(title: "Insert date", topPadding: 18)

            dateRow(label: "Today", offsetDays: 0)
            dateRow(label: "Yesterday", offsetDays: -1)
            dateRow(label: "Tomorrow", offsetDays: 1)
        }
    }

    private func dateRow(label: String, offsetDays: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offsetDays, to: Date()) ?? Date()
        let formatted = Self.dateFormatter.string(from: date)
        return CommandRow(
            leading: AnyView(
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.labelPrimary)
            ),
            title: "\(label) - \(formatted)"
        ) {
            perform { state.insertText(formatted) }
        }
    }

    // MARK: Insert attachment

    private var insertAttachmentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommandSectionHeader(title: "Insert attachment", topPadding: 18)

            // v1 is text-first: attachment insertion is gated off. Rows are shown for
            // design parity and dismiss gracefully until v2 re-enables the pickers.
            CommandRow(symbol: "photo", title: "Image") { perform {} }
            CommandRow(symbol: "paperclip", title: "File") { perform {} }
        }
    }

    // MARK: Insert formatting

    private var insertFormattingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommandSectionHeader(title: "Insert formatting", topPadding: 18)

            CommandRow(
                leading: headingGlyph("H1"),
                title: "Large header"
            ) { perform { state.editor.applyHeading(1) } }

            CommandRow(
                leading: headingGlyph("H2"),
                title: "Medium header"
            ) { perform { state.editor.applyHeading(2) } }

            CommandRow(
                leading: headingGlyph("H3"),
                title: "Small header"
            ) { perform { state.editor.applyHeading(3) } }

            CommandRow(symbol: "checklist", title: "Task list") {
                perform { state.editor.toggleChecklist() }
            }

            CommandRow(symbol: "list.bullet", title: "Bulleted list") {
                perform { state.editor.toggleBulletList() }
            }
        }
    }

    private func headingGlyph(_ text: String) -> AnyView {
        AnyView(
            Text(text)
                .font(.custom("HelveticaNeue-Bold", size: 15))
                .foregroundStyle(Color.labelPrimary)
        )
    }

    // MARK: Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.16)) { state.dismissCommandMenus() }
    }

    private func perform(_ work: () -> Void) {
        work()
        dismiss()
    }
}
