//
//  RichTextEditor.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 15/06/26.
//

import UIKit
import SwiftUI
import Combine
import QVACRuntime

// MARK: - RichTextController

final class RichTextController: ObservableObject {
    @Published var attributedText: NSAttributedString = NSAttributedString()
    @Published var isEmpty: Bool = true
    @Published var isFocused: Bool = false

    weak var textView: UITextView?
    var onMentionTrigger: (() -> Void)?
    var onSlashTrigger: (() -> Void)?

    /// A `@`/`/` command surface should only open at the start of the document or
    /// after whitespace — never mid-word (so "and/or", "a@b", "6/20" type literally).
    func shouldTriggerCommand(at range: NSRange) -> Bool {
        guard let tv = textView else { return true }
        let location = range.location
        guard location > 0 else { return true }
        let text = tv.attributedText.string as NSString
        guard location <= text.length else { return true }
        let previous = text.substring(with: NSRange(location: location - 1, length: 1))
        return previous == " " || previous == "\n" || previous == "\t"
    }

    private let defaultFont = UIFont(name: "HelveticaNeue", size: 15) ?? .systemFont(ofSize: 15)
    private let inlineCodeFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)

    func loadInitialContent(note: Note?) {
        let authoritativeBody = note?.content ?? ""

        if !authoritativeBody.isEmpty {
            attributedText = attributedString(from: SupportedMarkdownEditorBridge.presentation(markdown: authoritativeBody))
            isEmpty = false
            return
        }

        if let data = note?.contentRTF {
            // 1. Try our custom NSKeyedArchiver format (notes with inline audio).
            if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
                unarchiver.requiresSecureCoding = false
                let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
                unarchiver.finishDecoding()
                if let attrStr = decoded,
                   TextFirstV1Policy.shouldRestoreArchivedPresentationState(
                    archivedPresentationText: attrStr.string,
                    runtimeBody: authoritativeBody
                   ) {
                    attributedText = attrStr
                    isEmpty = authoritativeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    return
                }
            }
            // 2. Fall back to RTF (older notes).
            if let attrStr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ),
               TextFirstV1Policy.shouldRestoreArchivedPresentationState(
                archivedPresentationText: attrStr.string,
                runtimeBody: authoritativeBody
               ) {
                attributedText = attrStr
                isEmpty = authoritativeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return
            }
        }
        // 3. With no runtime-owned Note Body, start empty.
        attributedText = NSAttributedString()
        isEmpty = true
    }

    func supportedMarkdownBody() -> String {
        let presentation = SupportedMarkdownEditorPresentation(document: supportedMarkdownDocument())
        return SupportedMarkdownEditorBridge.markdown(from: presentation)
    }

    // MARK: Bold / Italic

    func toggleBold() {
        toggleTrait(.traitBold)
    }

    func toggleItalic() {
        toggleTrait(.traitItalic)
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else {
            // toggle typingAttributes for next character
            let current = tv.typingAttributes[.font] as? UIFont ?? defaultFont
            tv.typingAttributes[.font] = current.toggling(trait)
            return
        }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let font = (value as? UIFont) ?? defaultFont
            mutable.addAttribute(.font, value: font.toggling(trait), range: subRange)
        }
        tv.attributedText = mutable
        tv.selectedRange = range
        sync(from: tv)
    }

    // MARK: Underline / Strikethrough

    func toggleUnderline() {
        toggleIntAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
    }

    func toggleStrikethrough() {
        toggleIntAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }

    private func toggleIntAttribute(_ key: NSAttributedString.Key, value: Int) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else {
            let current = tv.typingAttributes[key] as? Int ?? 0
            tv.typingAttributes[key] = current == 0 ? value : 0
            return
        }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        var isOn = false
        mutable.enumerateAttribute(key, in: range, options: []) { val, _, _ in
            if (val as? Int ?? 0) != 0 { isOn = true }
        }
        mutable.enumerateAttribute(key, in: range, options: []) { _, subRange, _ in
            mutable.addAttribute(key, value: isOn ? 0 : value, range: subRange)
        }
        tv.attributedText = mutable
        tv.selectedRange = range
        sync(from: tv)
    }

    // MARK: Headings

    func applyHeading(_ level: Int) {
        guard let tv = textView else { return }
        let (font, _) = headingFont(level)
        applyFontToParagraph(font, in: tv, headingLevel: min(max(level, 1), 3))
    }

    func applyBody() {
        guard let tv = textView else { return }
        applyFontToParagraph(defaultFont, in: tv, headingLevel: nil)
    }

    private func headingFont(_ level: Int) -> (UIFont, CGFloat) {
        switch level {
        case 1:  return (UIFont(name: "HelveticaNeue-Bold", size: 28) ?? .boldSystemFont(ofSize: 28), 28)
        case 2:  return (UIFont(name: "HelveticaNeue-Bold", size: 22) ?? .boldSystemFont(ofSize: 22), 22)
        default: return (UIFont(name: "HelveticaNeue-Medium", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold), 18)
        }
    }

    private func applyFontToParagraph(_ font: UIFont, in tv: UITextView, headingLevel: Int?) {
        let fullText = tv.attributedText.string as NSString
        let cursorPos = tv.selectedRange.location
        let paragraphRange = fullText.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.addAttribute(.font, value: font, range: paragraphRange)
        if let headingLevel {
            mutable.addAttribute(.qvacSupportedMarkdownHeadingLevel, value: headingLevel, range: paragraphRange)
        } else {
            mutable.removeAttribute(.qvacSupportedMarkdownHeadingLevel, range: paragraphRange)
            mutable.removeAttribute(.qvacSupportedMarkdownBlockKind, range: paragraphRange)
        }
        let savedRange = tv.selectedRange
        tv.attributedText = mutable
        tv.selectedRange = savedRange
        sync(from: tv)
    }

    // MARK: Lists

    func toggleBulletList() {
        insertParagraphPrefix("• ", blockKind: SupportedMarkdownEditorBlockKind.bulletList)
    }

    func toggleNumberedList() {
        insertParagraphPrefix("1. ", blockKind: SupportedMarkdownEditorBlockKind.numberedList)
    }

    func toggleChecklist() {
        insertParagraphPrefix("☐ ", blockKind: SupportedMarkdownEditorBlockKind.checklist)
    }

    func insertPlainText(_ text: String) {
        insertAttributedText(NSAttributedString(string: text, attributes: bodyAttributes()))
    }

    func insertWikilink(title: String, markdown: String) {
        guard SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: title) != nil else { return }
        let insertion = NSAttributedString(
            string: "@\(title)",
            attributes: wikilinkMentionAttributes(title: title, markdown: markdown)
        )
        insertAttributedText(insertion, resetTypingAttributes: true)
    }

    private func insertAttributedText(
        _ insertion: NSAttributedString,
        resetTypingAttributes: Bool = false
    ) {
        guard let tv = textView else {
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            mutable.append(insertion)
            attributedText = mutable
            isEmpty = mutable.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return
        }

        let range = tv.selectedRange
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.replaceCharacters(in: range, with: insertion)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
        if resetTypingAttributes {
            tv.typingAttributes = bodyAttributes()
        }
        sync(from: tv)
    }

    func resetTypingAttributesIfNeededBeforeUserInsertion(
        in textView: UITextView,
        range: NSRange
    ) {
        guard isAdjacentToWikilinkToken(in: textView.attributedText, range: range) else {
            return
        }
        textView.typingAttributes = bodyAttributes()
    }

    private func isAdjacentToWikilinkToken(
        in attributedString: NSAttributedString,
        range: NSRange
    ) -> Bool {
        if range.length > 0 {
            var containsWikilink = false
            attributedString.enumerateAttribute(
                .qvacSupportedMarkdownWikilinkMarkdown,
                in: NSIntersectionRange(range, NSRange(location: 0, length: attributedString.length)),
                options: []
            ) { value, _, stop in
                if value != nil {
                    containsWikilink = true
                    stop.pointee = true
                }
            }
            if containsWikilink {
                return true
            }
        }

        return hasWikilinkTokenAttribute(in: attributedString, at: range.location - 1)
            || hasWikilinkTokenAttribute(in: attributedString, at: range.location)
    }

    private func hasWikilinkTokenAttribute(
        in attributedString: NSAttributedString,
        at location: Int
    ) -> Bool {
        guard location >= 0, location < attributedString.length else {
            return false
        }
        return attributedString.attribute(
            .qvacSupportedMarkdownWikilinkMarkdown,
            at: location,
            effectiveRange: nil
        ) != nil
    }

    // MARK: List auto-continue helpers

    private enum ListKind { case bullet, checklist, numbered(Int) }

    /// Detects whether `content` (a paragraph string, trailing newline already stripped)
    /// begins with a known list marker. Returns the kind and the exact marker string.
    private func listContext(_ content: String) -> (kind: ListKind, marker: String)? {
        if content.hasPrefix("• ")  { return (.bullet,    "• ") }
        if content.hasPrefix("☐ ") { return (.checklist, "☐ ") }
        if content.hasPrefix("☑ ") { return (.checklist, "☑ ") }   // checked → continue unchecked
        let digits = content.prefix { $0.isNumber }
        if !digits.isEmpty, content.dropFirst(digits.count).hasPrefix(". ") {
            return (.numbered(Int(digits) ?? 1), "\(digits). ")
        }
        return nil
    }

    /// Called by the coordinator when the user presses Return.
    /// Returns `true` if it consumed the event (auto-continued or exited a list).
    func handleNewline(at range: NSRange) -> Bool {
        guard let tv = textView else { return false }
        let full = tv.text as NSString
        let paraRange = full.paragraphRange(for: NSRange(location: range.location, length: 0))
        var content = full.substring(with: paraRange)
        if content.hasSuffix("\n") { content.removeLast() }
        guard let ctx = listContext(content) else { return false }

        let body = String(content.dropFirst(ctx.marker.count))
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)

        if body.trimmingCharacters(in: .whitespaces).isEmpty {
            // Empty list item → exit list: strip the marker, don't insert a newline.
            let removeRange = NSRange(location: paraRange.location, length: ctx.marker.utf16.count)
            mutable.deleteCharacters(in: removeRange)
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: paraRange.location, length: 0)
        } else {
            // Non-empty item → continue list with the next marker (numbered auto-increments).
            let next: String
            switch ctx.kind {
            case .bullet:          next = "• "
            case .checklist:       next = "☐ "
            case .numbered(let n): next = "\(n + 1). "
            }
            let insertion = NSMutableAttributedString(
                string: "\n" + next,
                attributes: [.font: defaultFont]
            )
            let blockKind: String
            switch ctx.kind {
            case .bullet:
                blockKind = SupportedMarkdownEditorBlockKind.bulletList
            case .checklist:
                blockKind = SupportedMarkdownEditorBlockKind.checklist
            case .numbered:
                blockKind = SupportedMarkdownEditorBlockKind.numberedList
            }
            insertion.addAttribute(
                .qvacSupportedMarkdownBlockKind,
                value: blockKind,
                range: NSRange(location: 1, length: insertion.length - 1)
            )
            mutable.insert(
                insertion,
                at: range.location
            )
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
        }
        sync(from: tv)
        return true
    }

    private func insertParagraphPrefix(_ prefix: String, blockKind: String) {
        guard let tv = textView else { return }
        let fullText = tv.text as NSString
        let cursorPos = tv.selectedRange.location
        let paraRange = fullText.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        let paraText = fullText.substring(with: paraRange)
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)

        if paraText.hasPrefix(prefix) {
            // already has prefix → remove it
            let removedRange = NSRange(location: paraRange.location, length: prefix.utf16.count)
            mutable.deleteCharacters(in: removedRange)
            let adjustedRange = NSRange(
                location: paraRange.location,
                length: max(0, paraRange.length - prefix.utf16.count)
            )
            mutable.removeAttribute(.qvacSupportedMarkdownBlockKind, range: adjustedRange)
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: max(0, cursorPos - prefix.utf16.count), length: 0)
        } else {
            let insertion = NSAttributedString(string: prefix, attributes: [.font: defaultFont])
            mutable.insert(insertion, at: paraRange.location)
            mutable.addAttribute(
                .qvacSupportedMarkdownBlockKind,
                value: blockKind,
                range: NSRange(location: paraRange.location, length: paraRange.length + prefix.utf16.count)
            )
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: cursorPos + prefix.utf16.count, length: 0)
        }
        sync(from: tv)
    }

    // MARK: Indent

    func indentIncrease() { adjustIndent(by: 20) }
    func indentDecrease() { adjustIndent(by: -20) }

    private func adjustIndent(by delta: CGFloat) {
        guard let tv = textView else { return }
        let fullText = tv.attributedText.string as NSString
        let cursorPos = tv.selectedRange.location
        let paraRange = fullText.paragraphRange(for: NSRange(location: cursorPos, length: 0))

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.enumerateAttribute(.paragraphStyle, in: paraRange, options: []) { val, subRange, _ in
            let existing = (val as? NSParagraphStyle) ?? NSParagraphStyle.default
            let style = existing.mutableCopy() as! NSMutableParagraphStyle
            style.headIndent = max(0, style.headIndent + delta)
            style.firstLineHeadIndent = max(0, style.firstLineHeadIndent + delta)
            mutable.addAttribute(.paragraphStyle, value: style, range: subRange)
        }
        let savedRange = tv.selectedRange
        tv.attributedText = mutable
        tv.selectedRange = savedRange
        sync(from: tv)
    }

    // MARK: Table

    /// Inserts a Markdown table at the current cursor position.
    /// A leading newline is added if the cursor isn't already at the start of a line;
    /// a trailing newline is always appended so typing continues below the table.
    func insertTable(host _: TableAttachmentHosting) {
        guard let tv = textView else { return }

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: defaultFont]
        let insertion = NSMutableAttributedString()

        let insertionPoint = tv.selectedRange.location
        let fullNSStr = tv.attributedText.string as NSString
        let needsLeadingNewline = insertionPoint > 0
            && fullNSStr.character(at: insertionPoint - 1) != 10  // 10 = '\n'
        if needsLeadingNewline {
            insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        }
        let tableStart = insertion.length
        insertion.append(NSAttributedString(
            string: "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |\n",
            attributes: bodyAttrs
        ))
        insertion.addAttribute(
            .qvacSupportedMarkdownBlockKind,
            value: SupportedMarkdownEditorBlockKind.table,
            range: NSRange(location: tableStart, length: insertion.length - tableStart)
        )

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.insert(insertion, at: insertionPoint)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: insertionPoint + insertion.length, length: 0)
        sync(from: tv)
    }

    /// Forces TextKit 2 to re-query all attachment bounds and rebuild attachment views.
    /// Used after rows/columns are added or removed from a TableTextAttachment.
    func refreshLayout() {
        guard let tv = textView else { return }
        let saved = tv.selectedRange
        // Reassigning attributed text causes TextKit 2 to call viewProvider(for:) and
        // attachmentBounds(for:) again for every attachment, rebuilding the grid UI.
        tv.attributedText = NSAttributedString(attributedString: tv.attributedText)
        tv.selectedRange = saved
        sync(from: tv)
    }

    // MARK: Inline audio

    /// Inserts an audio attachment card at the current cursor position.
    /// A newline is prepended if the cursor is not already at the start of a line,
    /// and a trailing newline is always appended so typing continues below the card.
    func insertAudio(_ attachment: Attachment, host: AudioAttachmentHosting) {
        guard let tv = textView else { return }

        let att = AudioTextAttachment(audioId: attachment.id.uuidString)
        att.host = host

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: defaultFont]
        let insertion = NSMutableAttributedString()

        let insertionPoint = tv.selectedRange.location
        let fullNSStr = tv.attributedText.string as NSString
        let needsLeadingNewline = insertionPoint > 0
            && fullNSStr.character(at: insertionPoint - 1) != 10  // 10 = '\n'
        if needsLeadingNewline {
            insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        }
        insertion.append(NSAttributedString(attachment: att))
        insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.insert(insertion, at: insertionPoint)
        tv.attributedText = mutable
        // Place cursor on the empty line below the card
        tv.selectedRange = NSRange(location: insertionPoint + insertion.length, length: 0)
        sync(from: tv)
    }

    /// Removes the inline audio attachment with the given `audioId` from the text view,
    /// also consuming its trailing newline.
    func removeAudioAttachment(audioId: String) {
        guard let tv = textView else { return }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        let fullNSStr = mutable.string as NSString
        var rangeToDelete: NSRange?

        mutable.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutable.length),
            options: .reverse
        ) { value, range, stop in
            if (value as? AudioTextAttachment)?.audioId == audioId {
                rangeToDelete = range
                stop.pointee = true
            }
        }

        guard var range = rangeToDelete else { return }
        // Consume the trailing newline so the card doesn't leave a blank line
        let afterEnd = range.location + range.length
        if afterEnd < fullNSStr.length && fullNSStr.character(at: afterEnd) == 10 {
            range.length += 1
        }

        mutable.deleteCharacters(in: range)
        tv.attributedText = mutable
        ensureTrailingTextSlot()
        sync(from: tv)
    }

    // MARK: Inline image

    /// Inserts an image attachment at the current cursor position.
    /// A newline is prepended if the cursor is not already at the start of a line,
    /// and a trailing newline is always appended so typing continues below the image.
    func insertImage(_ attachment: Attachment, host: ImageAttachmentHosting) {
        guard let tv = textView else { return }

        let att = ImageTextAttachment(imageId: attachment.id.uuidString)
        att.host = host

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: defaultFont]
        let insertion = NSMutableAttributedString()

        let insertionPoint = tv.selectedRange.location
        let fullNSStr = tv.attributedText.string as NSString
        let needsLeadingNewline = insertionPoint > 0
            && fullNSStr.character(at: insertionPoint - 1) != 10  // 10 = '\n'
        if needsLeadingNewline {
            insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        }
        insertion.append(NSAttributedString(attachment: att))
        insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.insert(insertion, at: insertionPoint)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: insertionPoint + insertion.length, length: 0)
        sync(from: tv)
    }

    /// Removes the inline image attachment with the given `imageId` from the text view,
    /// also consuming its trailing newline.
    func removeImageAttachment(imageId: String) {
        guard let tv = textView else { return }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        let fullNSStr = mutable.string as NSString
        var rangeToDelete: NSRange?

        mutable.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutable.length),
            options: .reverse
        ) { value, range, stop in
            if (value as? ImageTextAttachment)?.imageId == imageId {
                rangeToDelete = range
                stop.pointee = true
            }
        }

        guard var range = rangeToDelete else { return }
        let afterEnd = range.location + range.length
        if afterEnd < fullNSStr.length && fullNSStr.character(at: afterEnd) == 10 {
            range.length += 1
        }

        mutable.deleteCharacters(in: range)
        tv.attributedText = mutable
        ensureTrailingTextSlot()
        sync(from: tv)
    }

    // MARK: Inline file

    /// Inserts a file attachment card at the current cursor position.
    /// A newline is prepended if the cursor is not already at the start of a line,
    /// and a trailing newline is always appended so typing continues below the card.
    func insertFile(_ attachment: Attachment, host: FileAttachmentHosting) {
        guard let tv = textView else { return }

        let att = FileTextAttachment(fileId: attachment.id.uuidString)
        att.host = host

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: defaultFont]
        let insertion = NSMutableAttributedString()

        let insertionPoint = tv.selectedRange.location
        let fullNSStr = tv.attributedText.string as NSString
        let needsLeadingNewline = insertionPoint > 0
            && fullNSStr.character(at: insertionPoint - 1) != 10  // 10 = '\n'
        if needsLeadingNewline {
            insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
        }
        insertion.append(NSAttributedString(attachment: att))
        insertion.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.insert(insertion, at: insertionPoint)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: insertionPoint + insertion.length, length: 0)
        sync(from: tv)
    }

    /// Removes the inline file attachment with the given `fileId` from the text view,
    /// also consuming its trailing newline.
    func removeFileAttachment(fileId: String) {
        guard let tv = textView else { return }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        let fullNSStr = mutable.string as NSString
        var rangeToDelete: NSRange?

        mutable.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutable.length),
            options: .reverse
        ) { value, range, stop in
            if (value as? FileTextAttachment)?.fileId == fileId {
                rangeToDelete = range
                stop.pointee = true
            }
        }

        guard var range = rangeToDelete else { return }
        let afterEnd = range.location + range.length
        if afterEnd < fullNSStr.length && fullNSStr.character(at: afterEnd) == 10 {
            range.length += 1
        }

        mutable.deleteCharacters(in: range)
        tv.attributedText = mutable
        ensureTrailingTextSlot()
        sync(from: tv)
    }

    // MARK: Undo / Redo

    func undo() {
        guard let tv = textView, let mgr = tv.undoManager else { return }
        if mgr.canUndo { mgr.undo() }
        sync(from: tv)
    }

    func redo() {
        guard let tv = textView, let mgr = tv.undoManager else { return }
        if mgr.canRedo { mgr.redo() }
        sync(from: tv)
    }

    // MARK: Internal sync

    func sync(from tv: UITextView) {
        attributedText = tv.attributedText
        isEmpty = tv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Caret placement helpers

    /// Guarantees the document never ends on a non-text attachment glyph (U+FFFC).
    /// Appends a trailing "\n" when the last character is an attachment so the user
    /// always has a typeable slot below the last block. Idempotent — a document
    /// already ending in a newline (the normal post-insert state) is left untouched.
    func ensureTrailingTextSlot() {
        guard let tv = textView else { return }
        let str = tv.attributedText.string as NSString
        guard str.length > 0,
              str.character(at: str.length - 1) == 0xFFFC else { return }
        let saved = tv.selectedRange
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.append(NSAttributedString(string: "\n", attributes: [.font: defaultFont]))
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: min(saved.location, mutable.length), length: 0)
        sync(from: tv)
    }

    /// Places the caret at the very end of the document, appending a trailing
    /// text slot first when necessary, then makes the text view first responder.
    func focusAtEnd() {
        guard let tv = textView else { return }
        ensureTrailingTextSlot()
        tv.becomeFirstResponder()
        tv.selectedRange = NSRange(location: tv.attributedText.length, length: 0)
    }

    /// Moves the caret to the text position nearest to `point` (in text-view
    /// coordinates). Falls back to `focusAtEnd()` when `point` is below the
    /// last line of content.
    func placeCaret(at point: CGPoint) {
        guard let tv = textView else { return }
        let lastCaret = tv.caretRect(for: tv.endOfDocument)
        if point.y > lastCaret.maxY + 4 {
            focusAtEnd()
            return
        }
        guard let position = tv.closestPosition(to: point) else {
            focusAtEnd()
            return
        }
        tv.becomeFirstResponder()
        let offset = tv.offset(from: tv.beginningOfDocument, to: position)
        tv.selectedRange = NSRange(location: offset, length: 0)
    }

    // MARK: Supported Markdown bridge

    private func attributedString(from presentation: SupportedMarkdownEditorPresentation) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (offset, block) in presentation.blocks.enumerated() {
            if offset > 0 {
                result.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes()))
            }

            switch block {
            case .paragraph(let inline):
                appendInlineRuns(inline, to: result, baseAttributes: bodyAttributes())
            case .heading(let level, let inline):
                let start = result.length
                appendInlineRuns(inline, to: result, baseAttributes: bodyAttributes(font: headingFont(level).0))
                result.addAttribute(
                    .qvacSupportedMarkdownHeadingLevel,
                    value: min(max(level, 1), 3),
                    range: NSRange(location: start, length: result.length - start)
                )
            case .bulletList(let items):
                appendList(
                    items: items,
                    prefix: { _ in "• " },
                    blockKind: SupportedMarkdownEditorBlockKind.bulletList,
                    to: result
                )
            case .checklist(let items):
                let start = result.length
                for (index, item) in items.enumerated() {
                    if index > 0 {
                        result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
                    }
                    result.append(NSAttributedString(
                        string: item.isChecked ? "☑ " : "☐ ",
                        attributes: bodyAttributes()
                    ))
                    appendInlineRuns(item.inline, to: result, baseAttributes: bodyAttributes())
                }
                result.addAttribute(
                    .qvacSupportedMarkdownBlockKind,
                    value: SupportedMarkdownEditorBlockKind.checklist,
                    range: NSRange(location: start, length: result.length - start)
                )
            case .numberedList(let start, let items):
                appendList(
                    items: items,
                    prefix: { "\(start + $0). " },
                    blockKind: SupportedMarkdownEditorBlockKind.numberedList,
                    to: result
                )
            case .blockQuote(let inline):
                let start = result.length
                appendInlineRuns(inline, to: result, baseAttributes: bodyAttributes())
                result.addAttribute(
                    .qvacSupportedMarkdownBlockKind,
                    value: SupportedMarkdownEditorBlockKind.blockQuote,
                    range: NSRange(location: start, length: result.length - start)
                )
            case .divider:
                let start = result.length
                result.append(NSAttributedString(string: "---", attributes: bodyAttributes()))
                result.addAttribute(
                    .qvacSupportedMarkdownBlockKind,
                    value: SupportedMarkdownEditorBlockKind.divider,
                    range: NSRange(location: start, length: 3)
                )
            case .fencedCodeBlock(let language, let code):
                let start = result.length
                result.append(NSAttributedString(string: code, attributes: bodyAttributes(font: inlineCodeFont)))
                result.addAttribute(
                    .qvacSupportedMarkdownBlockKind,
                    value: SupportedMarkdownEditorBlockKind.fencedCodeBlock,
                    range: NSRange(location: start, length: result.length - start)
                )
                if let language {
                    result.addAttribute(
                        .qvacSupportedMarkdownCodeLanguage,
                        value: language,
                        range: NSRange(location: start, length: result.length - start)
                    )
                }
            case .table(let table):
                let start = result.length
                result.append(NSAttributedString(string: table.markdown(), attributes: bodyAttributes()))
                result.addAttribute(
                    .qvacSupportedMarkdownBlockKind,
                    value: SupportedMarkdownEditorBlockKind.table,
                    range: NSRange(location: start, length: result.length - start)
                )
            }
        }

        return result
    }

    private func appendList(
        items: [[SupportedMarkdownPresentationInline]],
        prefix: (Int) -> String,
        blockKind: String,
        to result: NSMutableAttributedString
    ) {
        let start = result.length
        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes()))
            }
            result.append(NSAttributedString(string: prefix(index), attributes: bodyAttributes()))
            appendInlineRuns(item, to: result, baseAttributes: bodyAttributes())
        }
        result.addAttribute(
            .qvacSupportedMarkdownBlockKind,
            value: blockKind,
            range: NSRange(location: start, length: result.length - start)
        )
    }

    private func appendInlineRuns(
        _ runs: [SupportedMarkdownPresentationInline],
        to result: NSMutableAttributedString,
        baseAttributes: [NSAttributedString.Key: Any]
    ) {
        for run in runs {
            var attributes = baseAttributes
            var font = attributes[.font] as? UIFont ?? defaultFont

            if run.styles.contains(.inlineCode) {
                font = inlineCodeFont
                attributes[.qvacSupportedMarkdownInlineCode] = true
            }
            if run.styles.contains(.bold) {
                font = font.adding(.traitBold)
            }
            if run.styles.contains(.italic) {
                font = font.adding(.traitItalic)
            }
            if run.styles.contains(.underline) {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if run.styles.contains(.strikethrough) {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            attributes[.font] = font

            appendTextRenderingWikilinks(run.text, to: result, attributes: attributes)
        }
    }

    private func bodyAttributes(font: UIFont? = nil) -> [NSAttributedString.Key: Any] {
        [.font: font ?? defaultFont]
    }

    private func wikilinkMentionAttributes(
        title: String,
        markdown: String,
        baseAttributes: [NSAttributedString.Key: Any]? = nil
    ) -> [NSAttributedString.Key: Any] {
        var attributes = baseAttributes ?? bodyAttributes()
        attributes[.font] = UIFont(name: "HelveticaNeue-Medium", size: 15)
            ?? UIFont.systemFont(ofSize: 15, weight: .medium)
        attributes[.foregroundColor] = UIColor.systemBlue
        attributes[.backgroundColor] = UIColor.systemBlue.withAlphaComponent(0.12)
        attributes[.qvacSupportedMarkdownWikilinkTitle] = title
        attributes[.qvacSupportedMarkdownWikilinkMarkdown] = markdown
        return attributes
    }

    private func appendTextRenderingWikilinks(
        _ text: String,
        to result: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let nsText = text as NSString
        var cursor = 0

        while cursor < nsText.length {
            let remaining = NSRange(location: cursor, length: nsText.length - cursor)
            let opening = nsText.range(of: "[[", options: [], range: remaining)
            guard opening.location != NSNotFound else {
                appendPlainText(nsText.substring(with: remaining), to: result, attributes: attributes)
                return
            }

            if opening.location > cursor {
                appendPlainText(
                    nsText.substring(with: NSRange(location: cursor, length: opening.location - cursor)),
                    to: result,
                    attributes: attributes
                )
            }

            let titleStart = opening.location + opening.length
            let closingSearchRange = NSRange(location: titleStart, length: nsText.length - titleStart)
            let closing = nsText.range(of: "]]", options: [], range: closingSearchRange)
            guard closing.location != NSNotFound else {
                appendPlainText(
                    nsText.substring(with: NSRange(location: opening.location, length: nsText.length - opening.location)),
                    to: result,
                    attributes: attributes
                )
                return
            }

            let title = nsText.substring(with: NSRange(location: titleStart, length: closing.location - titleStart))
            let markdown = nsText.substring(with: NSRange(location: opening.location, length: closing.location + closing.length - opening.location))
            if SupportedMarkdownEditorBridge.wikilinkInsertionText(forNoteTitle: title) != nil {
                result.append(NSAttributedString(
                    string: "@\(title)",
                    attributes: wikilinkMentionAttributes(title: title, markdown: markdown, baseAttributes: attributes)
                ))
            } else {
                appendPlainText(markdown, to: result, attributes: attributes)
            }
            cursor = closing.location + closing.length
        }
    }

    private func appendPlainText(
        _ text: String,
        to result: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard !text.isEmpty else { return }
        result.append(NSAttributedString(string: text, attributes: attributes))
    }

    private func supportedMarkdownDocument() -> SupportedMarkdownDocument {
        let ranges = attributedBlockRanges()
        let blocks = ranges.map { markdownBlock(in: $0.range, text: $0.text) }
        return SupportedMarkdownDocument(blocks: blocks)
    }

    private func attributedBlockRanges() -> [(range: NSRange, text: String)] {
        let fullText = attributedText.string as NSString
        guard fullText.length > 0 else { return [] }

        return SupportedMarkdownEditorBridge.blockRanges(
            in: attributedText.string,
            protectedRanges: protectedMarkdownBlockRanges()
        ).map { range in
            let nsRange = NSRange(location: range.location, length: range.length)
            return (nsRange, fullText.substring(with: nsRange))
        }
    }

    private func protectedMarkdownBlockRanges() -> [SupportedMarkdownEditorTextRange] {
        var ranges: [SupportedMarkdownEditorTextRange] = []
        attributedText.enumerateAttribute(
            .qvacSupportedMarkdownBlockKind,
            in: NSRange(location: 0, length: attributedText.length),
            options: []
        ) { value, range, _ in
            guard value as? String == SupportedMarkdownEditorBlockKind.fencedCodeBlock else { return }
            ranges.append(SupportedMarkdownEditorTextRange(location: range.location, length: range.length))
        }
        return ranges
    }

    private func markdownBlock(in range: NSRange, text: String) -> SupportedMarkdownBlock {
        let attributes = attributedText.attributes(at: range.location, effectiveRange: nil)
        if let level = attributes[.qvacSupportedMarkdownHeadingLevel] as? Int {
            return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                text: text,
                inline: inlineRuns(in: range, suppressFontTraits: true),
                intent: .heading(level: level)
            )
        }
        let inline = inlineRuns(in: range)
        if let blockKind = attributes[.qvacSupportedMarkdownBlockKind] as? String {
            switch blockKind {
            case SupportedMarkdownEditorBlockKind.blockQuote:
                return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                    text: text,
                    inline: inline,
                    intent: .blockQuote
                )
            case SupportedMarkdownEditorBlockKind.divider:
                return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                    text: text,
                    inline: inline,
                    intent: .divider
                )
            case SupportedMarkdownEditorBlockKind.fencedCodeBlock:
                return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                    text: text,
                    inline: inline,
                    intent: .fencedCodeBlock(
                        language: attributes[.qvacSupportedMarkdownCodeLanguage] as? String
                    )
                )
            case SupportedMarkdownEditorBlockKind.bulletList:
                if let bulletList = bulletList(in: range) {
                    return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                        text: text,
                        inline: inline,
                        intent: .bulletList(items: bulletList)
                    )
                }
            case SupportedMarkdownEditorBlockKind.checklist:
                if let checklist = checklist(in: range) {
                    return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                        text: text,
                        inline: inline,
                        intent: .checklist(items: checklist)
                    )
                }
            case SupportedMarkdownEditorBlockKind.numberedList:
                if let numberedList = numberedList(in: range) {
                    return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                        text: text,
                        inline: inline,
                        intent: .numberedList(start: numberedList.start, items: numberedList.items)
                    )
                }
            case SupportedMarkdownEditorBlockKind.table:
                if let table = SupportedMarkdownEditorBridge.tableFromEditorParagraph(text: text) {
                    return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
                        text: text,
                        inline: inline,
                        intent: .table(table)
                    )
                }
            default:
                break
            }
        }
        return SupportedMarkdownEditorBridge.blockFromEditorParagraph(
            text: text,
            inline: inline,
            intent: nil
        )
    }

    private func bulletList(in range: NSRange) -> [[SupportedMarkdownInline]]? {
        prefixedList(in: range, prefixes: ["• "]).map { lines in
            lines.map { $0.runs }
        }
    }

    private func checklist(in range: NSRange) -> [SupportedMarkdownChecklistItem]? {
        guard let lines = prefixedList(in: range, prefixes: ["☐ ", "☑ "]) else { return nil }
        return lines.map { line in
            SupportedMarkdownChecklistItem(
                isChecked: line.prefix == "☑ ",
                text: line.runs
            )
        }
    }

    private func numberedList(in range: NSRange) -> (start: Int, items: [[SupportedMarkdownInline]])? {
        let lines = lineRanges(in: range)
        guard !lines.isEmpty else { return nil }
        var numbers: [Int] = []
        var items: [[SupportedMarkdownInline]] = []

        for line in lines {
            let digits = line.text.prefix { $0.isNumber }
            guard !digits.isEmpty,
                  line.text.dropFirst(digits.count).hasPrefix(". "),
                  let number = Int(digits) else {
                return nil
            }
            let prefixLength = digits.utf16.count + 2
            numbers.append(number)
            items.append(inlineRuns(in: NSRange(
                location: line.range.location + prefixLength,
                length: max(0, line.range.length - prefixLength)
            )))
        }

        guard let start = numbers.first else { return nil }
        return (start, items)
    }

    private func prefixedList(
        in range: NSRange,
        prefixes: [String]
    ) -> [(prefix: String, runs: [SupportedMarkdownInline])]? {
        let lines = lineRanges(in: range)
        guard !lines.isEmpty else { return nil }
        var prefixedLines: [(prefix: String, runs: [SupportedMarkdownInline])] = []

        for line in lines {
            guard let prefix = prefixes.first(where: { line.text.hasPrefix($0) }) else { return nil }
            let prefixLength = prefix.utf16.count
            prefixedLines.append((
                prefix,
                inlineRuns(in: NSRange(
                    location: line.range.location + prefixLength,
                    length: max(0, line.range.length - prefixLength)
                ))
            ))
        }

        return prefixedLines
    }

    private func lineRanges(in range: NSRange) -> [(range: NSRange, text: String)] {
        let fullText = attributedText.string as NSString
        let end = range.location + range.length
        var lines: [(NSRange, String)] = []
        var location = range.location

        while location < end {
            var lineEnd = location
            while lineEnd < end, fullText.character(at: lineEnd) != 10 {
                lineEnd += 1
            }
            let lineRange = NSRange(location: location, length: lineEnd - location)
            lines.append((lineRange, fullText.substring(with: lineRange)))
            location = lineEnd < end ? lineEnd + 1 : lineEnd
        }

        return lines
    }

    private func inlineRuns(
        in range: NSRange,
        suppressFontTraits: Bool = false
    ) -> [SupportedMarkdownInline] {
        guard range.length > 0 else { return [.plain("")] }

        let fullText = attributedText.string as NSString
        var runs: [SupportedMarkdownInline] = []

        attributedText.enumerateAttributes(in: range, options: []) { attributes, subRange, _ in
            let text = fullText.substring(with: subRange)
                .replacingOccurrences(of: "\u{FFFC}", with: "")
            guard !text.isEmpty else { return }

            if let wikilinkMarkdown = attributes[.qvacSupportedMarkdownWikilinkMarkdown] as? String {
                if runs.last?.styles == [] {
                    let previous = runs.removeLast()
                    runs.append(SupportedMarkdownInline(text: previous.text + wikilinkMarkdown, styles: []))
                } else {
                    runs.append(SupportedMarkdownInline(text: wikilinkMarkdown, styles: []))
                }
                return
            }

            var styles = Set<SupportedMarkdownInlineStyle>()
            if !suppressFontTraits,
               let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { styles.insert(.bold) }
                if traits.contains(.traitItalic) { styles.insert(.italic) }
            }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 {
                styles.insert(.underline)
            }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 {
                styles.insert(.strikethrough)
            }
            if (attributes[.qvacSupportedMarkdownInlineCode] as? Bool) == true {
                styles.insert(.inlineCode)
            }

            if runs.last?.styles == styles {
                let previous = runs.removeLast()
                runs.append(SupportedMarkdownInline(text: previous.text + text, styles: styles))
            } else {
                runs.append(SupportedMarkdownInline(text: text, styles: styles))
            }
        }

        return runs.isEmpty ? [.plain("")] : runs
    }
}

private enum SupportedMarkdownEditorBlockKind {
    static let blockQuote = "blockQuote"
    static let divider = "divider"
    static let fencedCodeBlock = "fencedCodeBlock"
    static let bulletList = "bulletList"
    static let checklist = "checklist"
    static let numberedList = "numberedList"
    static let table = "table"
}

private extension NSAttributedString.Key {
    static let qvacSupportedMarkdownHeadingLevel = NSAttributedString.Key("qvac.supportedMarkdown.headingLevel")
    static let qvacSupportedMarkdownBlockKind = NSAttributedString.Key("qvac.supportedMarkdown.blockKind")
    static let qvacSupportedMarkdownInlineCode = NSAttributedString.Key("qvac.supportedMarkdown.inlineCode")
    static let qvacSupportedMarkdownCodeLanguage = NSAttributedString.Key("qvac.supportedMarkdown.codeLanguage")
    static let qvacSupportedMarkdownWikilinkTitle = NSAttributedString.Key("qvac.supportedMarkdown.wikilinkTitle")
    static let qvacSupportedMarkdownWikilinkMarkdown = NSAttributedString.Key("qvac.supportedMarkdown.wikilinkMarkdown")
}

// MARK: - UIFont trait toggle helper

private extension UIFont {
    func adding(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let desc = fontDescriptor
        var traits = desc.symbolicTraits
        traits.insert(trait)
        let newDesc = desc.withSymbolicTraits(traits) ?? desc
        return UIFont(descriptor: newDesc, size: pointSize)
    }

    func toggling(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let desc = fontDescriptor
        var traits = desc.symbolicTraits
        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }
        let newDesc = desc.withSymbolicTraits(traits) ?? desc
        return UIFont(descriptor: newDesc, size: pointSize)
    }
}

// MARK: - RichTextEditor (UIViewRepresentable)

struct RichTextEditor<Accessory: View>: UIViewRepresentable {
    @ObservedObject var controller: RichTextController
    var accessory: () -> Accessory

    init(controller: RichTextController, @ViewBuilder accessory: @escaping () -> Accessory) {
        self._controller = ObservedObject(wrappedValue: controller)
        self.accessory = accessory
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: true)
        tv.delegate = context.coordinator
        tv.font = UIFont(name: "HelveticaNeue", size: 15) ?? .systemFont(ofSize: 15)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.attributedText = controller.attributedText
        controller.textView = tv

        // Tap recognizer for caret placement on attachment padding and the empty area
        // below content. cancelsTouchesInView=false lets attachment interactive subviews
        // (image, card buttons, table cells) still handle their own taps unimpeded.
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        // Fix legacy notes that were persisted ending directly on an attachment.
        controller.ensureTrailingTextSlot()

        let host = UIHostingController(rootView: accessory())
        host.view.frame = CGRect(x: 0, y: 0, width: 0, height: 48)
        host.view.autoresizingMask = [.flexibleWidth]
        host.view.backgroundColor = .clear
        tv.inputAccessoryView = host.view
        context.coordinator.hostingController = host

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Only sync when changed externally (e.g. on appear load), not while user types
        if tv.attributedText != controller.attributedText && !context.coordinator.isEditing {
            let savedRange = tv.selectedRange
            tv.attributedText = controller.attributedText
            tv.selectedRange = savedRange
        }
        context.coordinator.hostingController?.rootView = accessory()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        let controller: RichTextController
        var isEditing = false
        var hostingController: UIHostingController<Accessory>?

        init(controller: RichTextController) {
            self.controller = controller
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Intercept Return key to auto-continue or exit list items.
            if text == "\n", controller.handleNewline(at: range) { return false }
            if text == "@", controller.shouldTriggerCommand(at: range) {
                controller.onMentionTrigger?()
                return false
            }
            if text == "/", controller.shouldTriggerCommand(at: range) {
                controller.onSlashTrigger?()
                return false
            }
            if !text.isEmpty {
                controller.resetTypingAttributesIfNeededBeforeUserInsertion(in: textView, range: range)
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            controller.sync(from: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            controller.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            controller.isFocused = false
        }

        // MARK: Caret placement

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let tv = controller.textView else { return }
            controller.placeCaret(at: g.location(in: tv))
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            // Allow caret placement on the text view's own background and on the
            // transparent top-padding area of attachment containers. Taps on interactive
            // inner subviews (image views, card buttons, sliders, table cells) are NOT
            // AttachmentContainerView instances, so they keep handling their own taps.
            return touch.view === controller.textView || touch.view is AttachmentContainerView
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Let UITextInteraction (caret, magnifier, double-tap selection) run
            // alongside our recognizer without either cancelling the other.
            return true
        }
    }
}

// MARK: - AttachmentContainerView

/// Marker UIView subclass used as the root container of every non-text attachment
/// view provider (image, file, audio, table). Taps on this view — the bare top-
/// padding area between blocks — reach `Coordinator.shouldReceive`, which passes
/// them to `placeCaret(at:)`. Taps on the inner interactive subviews (image view,
/// card buttons, table text fields, slider) are NOT an `AttachmentContainerView`
/// touch, so `shouldReceive` rejects them and those subviews handle their own taps.
final class AttachmentContainerView: UIView {}
