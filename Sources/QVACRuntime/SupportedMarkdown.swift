import Foundation

public struct SupportedMarkdownDocument: Equatable, Sendable {
    public let blocks: [SupportedMarkdownBlock]

    public init(blocks: [SupportedMarkdownBlock]) {
        self.blocks = blocks
    }

    public init(markdown: String) {
        self.blocks = Self.parse(markdown)
    }

    public func markdown() -> String {
        blocks.map { $0.markdown() }.joined(separator: "\n\n")
    }

    private static func parse(_ markdown: String) -> [SupportedMarkdownBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        return splitTopLevelBlocks(in: normalized).map { rawBlock in
            let block = rawBlock.trimmingCharacters(in: .newlines)
            if block.hasPrefix("### ") {
                return .heading(level: 3, text: parseInline(String(block.dropFirst(4))))
            }
            if block.hasPrefix("## ") {
                return .heading(level: 2, text: parseInline(String(block.dropFirst(3))))
            }
            if block.hasPrefix("# ") {
                return .heading(level: 1, text: parseInline(String(block.dropFirst(2))))
            }
            if let table = parseTable(block) {
                return .table(table)
            }
            if let checklist = parseChecklist(block) {
                return .checklist(items: checklist)
            }
            if let bulletList = parseBulletList(block) {
                return .bulletList(items: bulletList)
            }
            if let numberedList = parseNumberedList(block) {
                return .numberedList(start: numberedList.start, items: numberedList.items)
            }
            if block == "---" {
                return .divider
            }
            if block.hasPrefix("> ") {
                return .blockQuote(text: parseInline(String(block.dropFirst(2))))
            }
            if let fencedCodeBlock = parseFencedCodeBlock(block) {
                return fencedCodeBlock
            }
            return .paragraph(text: parseInline(block))
        }
    }

    private static func splitTopLevelBlocks(in markdown: String) -> [String] {
        var blocks: [String] = []
        var currentLines: [String] = []
        var isInsideFencedCodeBlock = false

        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                currentLines.append(line)
                isInsideFencedCodeBlock.toggle()
                continue
            }

            if !isInsideFencedCodeBlock,
               line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentLines.isEmpty {
                    blocks.append(currentLines.joined(separator: "\n"))
                    currentLines = []
                }
                continue
            }

            currentLines.append(line)
        }

        if !currentLines.isEmpty {
            blocks.append(currentLines.joined(separator: "\n"))
        }

        return blocks
    }

    private static func parseBulletList(_ block: String) -> [[SupportedMarkdownInline]]? {
        let lines = block.components(separatedBy: "\n")
        guard !lines.isEmpty,
              lines.allSatisfy({ $0.hasPrefix("- ") && !$0.hasPrefix("- [") }) else {
            return nil
        }
        return lines.map { parseInline(String($0.dropFirst(2))) }
    }

    private static func parseChecklist(_ block: String) -> [SupportedMarkdownChecklistItem]? {
        let lines = block.components(separatedBy: "\n")
        guard !lines.isEmpty else { return nil }
        var items: [SupportedMarkdownChecklistItem] = []

        for line in lines {
            if line.hasPrefix("- [ ] ") {
                items.append(SupportedMarkdownChecklistItem(
                    isChecked: false,
                    text: parseInline(String(line.dropFirst(6)))
                ))
            } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                items.append(SupportedMarkdownChecklistItem(
                    isChecked: true,
                    text: parseInline(String(line.dropFirst(6)))
                ))
            } else {
                return nil
            }
        }

        return items
    }

    private static func parseNumberedList(_ block: String) -> (start: Int, items: [[SupportedMarkdownInline]])? {
        let lines = block.components(separatedBy: "\n")
        guard !lines.isEmpty else { return nil }
        var numbers: [Int] = []
        var items: [[SupportedMarkdownInline]] = []

        for line in lines {
            guard let item = parseNumberedListItem(line) else { return nil }
            numbers.append(item.number)
            items.append(parseInline(item.text))
        }

        guard let start = numbers.first else { return nil }
        return (start, items)
    }

    private static func parseNumberedListItem(_ line: String) -> (number: Int, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty,
              line.dropFirst(digits.count).hasPrefix(". "),
              let number = Int(digits) else {
            return nil
        }
        return (number, String(line.dropFirst(digits.count + 2)))
    }

    private static func parseTable(_ block: String) -> SupportedMarkdownTable? {
        let lines = block.components(separatedBy: "\n")
        guard lines.count >= 2,
              let header = parseTableRow(lines[0]),
              let separator = parseTableRow(lines[1]),
              !header.isEmpty,
              header.count == separator.count,
              separator.allSatisfy(isTableSeparatorCell) else {
            return nil
        }

        let rows = lines.dropFirst(2).map { parseTableRow($0) }
        guard rows.allSatisfy({ $0?.count == header.count }) else { return nil }
        return SupportedMarkdownTable(header: header, rows: rows.compactMap { $0 })
    }

    private static func parseTableRow(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else { return nil }
        return trimmed
            .dropFirst()
            .dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isTableSeparatorCell(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == ":" }
    }

    private static func parseFencedCodeBlock(_ block: String) -> SupportedMarkdownBlock? {
        let lines = block.components(separatedBy: "\n")
        guard let first = lines.first,
              first.hasPrefix("```"),
              lines.count >= 2,
              lines.last == "```" else {
            return nil
        }

        let language = String(first.dropFirst(3))
        return .fencedCodeBlock(
            language: language.isEmpty ? nil : language,
            code: lines.dropFirst().dropLast().joined(separator: "\n")
        )
    }

    private static func parseInline(_ markdown: String) -> [SupportedMarkdownInline] {
        var runs: [SupportedMarkdownInline] = []
        var plain = ""
        var index = markdown.startIndex

        func flushPlain() {
            guard !plain.isEmpty else { return }
            runs.append(.plain(plain))
            plain = ""
        }

        func styledRuns(
            from content: String,
            adding addedStyles: Set<SupportedMarkdownInlineStyle>,
            parsesInnerMarkdown: Bool = true
        ) -> [SupportedMarkdownInline] {
            guard parsesInnerMarkdown else {
                return [SupportedMarkdownInline(text: content, styles: addedStyles)]
            }

            return parseInline(content).map { run in
                SupportedMarkdownInline(text: run.text, styles: run.styles.union(addedStyles))
            }
        }

        func consumeDelimited(
            opening: String,
            closing: String,
            style: SupportedMarkdownInlineStyle
        ) -> Bool {
            guard markdown[index...].hasPrefix(opening) else { return false }
            let contentStart = markdown.index(index, offsetBy: opening.count)
            guard let closingRange = markdown.range(of: closing, range: contentStart..<markdown.endIndex) else {
                return false
            }
            flushPlain()
            let content = String(markdown[contentStart..<closingRange.lowerBound])
            runs.append(contentsOf: styledRuns(
                from: content,
                adding: [style],
                parsesInnerMarkdown: style != .inlineCode
            ))
            index = closingRange.upperBound
            return true
        }

        while index < markdown.endIndex {
            if markdown[index] == "\\" {
                let escapedIndex = markdown.index(after: index)
                if escapedIndex < markdown.endIndex {
                    plain.append(markdown[escapedIndex])
                    index = markdown.index(after: escapedIndex)
                    continue
                }
            }

            if consumeDelimited(opening: "`", closing: "`", style: .inlineCode) { continue }
            if markdown[index...].hasPrefix("***") {
                let contentStart = markdown.index(index, offsetBy: 3)
                if let closingRange = markdown.range(of: "***", range: contentStart..<markdown.endIndex) {
                    flushPlain()
                    let content = String(markdown[contentStart..<closingRange.lowerBound])
                    runs.append(contentsOf: styledRuns(from: content, adding: [.bold, .italic]))
                    index = closingRange.upperBound
                    continue
                }
            }
            if consumeDelimited(opening: "**", closing: "**", style: .bold) { continue }
            if consumeDelimited(opening: "~~", closing: "~~", style: .strikethrough) { continue }
            if consumeDelimited(opening: "<u>", closing: "</u>", style: .underline) { continue }
            if consumeDelimited(opening: "*", closing: "*", style: .italic) { continue }

            plain.append(markdown[index])
            index = markdown.index(after: index)
        }

        flushPlain()
        return runs.isEmpty ? [.plain("")] : runs
    }
}

public enum SupportedMarkdownBlock: Equatable, Sendable {
    case paragraph(text: [SupportedMarkdownInline])
    case heading(level: Int, text: [SupportedMarkdownInline])
    case bulletList(items: [[SupportedMarkdownInline]])
    case checklist(items: [SupportedMarkdownChecklistItem])
    case numberedList(start: Int, items: [[SupportedMarkdownInline]])
    case blockQuote(text: [SupportedMarkdownInline])
    case divider
    case fencedCodeBlock(language: String?, code: String)
    case table(SupportedMarkdownTable)

    fileprivate func markdown() -> String {
        switch self {
        case .paragraph(let text):
            SupportedMarkdownEscaping.escapeParagraphBlockMarkers(text.markdown())
        case .heading(let level, let text):
            "\(String(repeating: "#", count: min(max(level, 1), 3))) \(text.markdown())"
        case .bulletList(let items):
            items.map { "- \($0.markdown())" }.joined(separator: "\n")
        case .checklist(let items):
            items.map { "- [\($0.isChecked ? "x" : " ")] \($0.text.markdown())" }.joined(separator: "\n")
        case .numberedList(let start, let items):
            items.enumerated()
                .map { offset, item in "\(start + offset). \(item.markdown())" }
                .joined(separator: "\n")
        case .blockQuote(let text):
            "> \(text.markdown())"
        case .divider:
            "---"
        case .fencedCodeBlock(let language, let code):
            "```\(language ?? "")\n\(code)\n```"
        case .table(let table):
            table.markdown()
        }
    }
}

public struct SupportedMarkdownEditorPresentation: Equatable, Sendable {
    public let blocks: [SupportedMarkdownPresentationBlock]

    public init(blocks: [SupportedMarkdownPresentationBlock]) {
        self.blocks = blocks
    }

    public init(markdown: String) {
        self.init(document: SupportedMarkdownDocument(markdown: markdown))
    }

    public init(document: SupportedMarkdownDocument) {
        self.blocks = document.blocks.map(Self.presentationBlock)
    }

    private static func presentationBlock(_ block: SupportedMarkdownBlock) -> SupportedMarkdownPresentationBlock {
        switch block {
        case .paragraph(let text):
            .paragraph(inline: presentationInline(text))
        case .heading(let level, let text):
            .heading(level: level, inline: presentationInline(text))
        case .bulletList(let items):
            .bulletList(items: items.map(presentationInline))
        case .checklist(let items):
            .checklist(items: items.map { item in
                SupportedMarkdownPresentationChecklistItem(
                    isChecked: item.isChecked,
                    inline: presentationInline(item.text)
                )
            })
        case .numberedList(let start, let items):
            .numberedList(start: start, items: items.map(presentationInline))
        case .blockQuote(let text):
            .blockQuote(inline: presentationInline(text))
        case .divider:
            .divider
        case .fencedCodeBlock(let language, let code):
            .fencedCodeBlock(language: language, code: code)
        case .table(let table):
            .table(table)
        }
    }

    private static func presentationInline(
        _ inline: [SupportedMarkdownInline]
    ) -> [SupportedMarkdownPresentationInline] {
        inline.map { SupportedMarkdownPresentationInline(text: $0.text, styles: $0.styles) }
    }
}

public enum SupportedMarkdownEditorBridge {
    public static func presentation(markdown: String) -> SupportedMarkdownEditorPresentation {
        SupportedMarkdownEditorPresentation(markdown: markdown)
    }

    public static func wikilinkInsertionText(forNoteTitle title: String) -> String? {
        guard !title.isEmpty,
              !title.contains("\n"),
              !title.contains("\r"),
              !title.contains("]]") else {
            return nil
        }
        return "[[\(title)]]"
    }

    public static func markdown(from presentation: SupportedMarkdownEditorPresentation) -> String {
        SupportedMarkdownDocument(presentation: presentation).markdown()
    }

    public static func editorContent(markdown: String) -> SupportedMarkdownEditorContent {
        SupportedMarkdownEditorContent(presentation: presentation(markdown: markdown))
    }

    public static func markdown(fromEditorContent content: SupportedMarkdownEditorContent) -> String {
        let blocks = blockRanges(
            in: content.text,
            protectedRanges: content.protectedBlocks.map(\.range)
        ).map { range -> SupportedMarkdownBlock in
            let text = substring(in: content.text, range: range)
            if let protectedBlock = content.protectedBlocks.first(where: { $0.range == range }) {
                switch protectedBlock.kind {
                case .fencedCodeBlock(let language):
                    return .fencedCodeBlock(language: language, code: text)
                }
            }
            return .paragraph(text: [.plain(text)])
        }
        return SupportedMarkdownDocument(blocks: blocks).markdown()
    }

    public static func tableFromEditorParagraph(text: String) -> SupportedMarkdownTable? {
        guard case .table(let table)? = SupportedMarkdownDocument(markdown: text).blocks.first else {
            return nil
        }
        return table
    }

    public static func blockFromEditorParagraph(
        text: String,
        inline: [SupportedMarkdownInline],
        intent: SupportedMarkdownEditorBlockIntent?
    ) -> SupportedMarkdownBlock {
        switch intent {
        case nil:
            return .paragraph(text: inline)
        case .heading(let level):
            return .heading(level: level, text: inline)
        case .blockQuote:
            return .blockQuote(text: inline)
        case .divider:
            return .divider
        case .fencedCodeBlock(let language):
            return .fencedCodeBlock(language: language, code: text)
        case .bulletList(let items):
            return .bulletList(items: items)
        case .checklist(let items):
            return .checklist(items: items)
        case .numberedList(let start, let items):
            return .numberedList(start: start, items: items)
        case .table(let table):
            return .table(table)
        }
    }

    public static func blockRanges(
        in text: String,
        protectedRanges: [SupportedMarkdownEditorTextRange]
    ) -> [SupportedMarkdownEditorTextRange] {
        let nsText = text as NSString
        guard nsText.length > 0 else { return [] }

        var ranges: [SupportedMarkdownEditorTextRange] = []
        var start = 0
        var lineStart = 0
        var isInsideRawFencedCodeBlock = false

        while lineStart < nsText.length {
            var lineEnd = lineStart
            while lineEnd < nsText.length, nsText.character(at: lineEnd) != 10 {
                lineEnd += 1
            }

            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            let line = nsText.substring(with: lineRange)
            let isBlankLine = line.trimmingCharacters(in: .whitespaces).isEmpty

            if line.hasPrefix("```") {
                isInsideRawFencedCodeBlock.toggle()
            } else if isBlankLine,
                      !isInsideRawFencedCodeBlock,
                      !protectedRanges.contains(where: { $0.contains(lineStart) }) {
                appendRange(location: start, length: max(0, lineStart - start - 1), to: &ranges)
                start = lineEnd < nsText.length ? lineEnd + 1 : lineEnd
            }

            lineStart = lineEnd < nsText.length ? lineEnd + 1 : lineEnd
        }

        appendRange(location: start, length: nsText.length - start, to: &ranges)
        return ranges
    }

    private static func appendRange(
        location: Int,
        length: Int,
        to ranges: inout [SupportedMarkdownEditorTextRange]
    ) {
        guard length > 0 else { return }
        ranges.append(SupportedMarkdownEditorTextRange(location: location, length: length))
    }

    private static func substring(in text: String, range: SupportedMarkdownEditorTextRange) -> String {
        (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
    }
}

public enum SupportedMarkdownEditorBlockIntent: Equatable, Sendable {
    case heading(level: Int)
    case blockQuote
    case divider
    case fencedCodeBlock(language: String?)
    case bulletList(items: [[SupportedMarkdownInline]])
    case checklist(items: [SupportedMarkdownChecklistItem])
    case numberedList(start: Int, items: [[SupportedMarkdownInline]])
    case table(SupportedMarkdownTable)
}

public extension SupportedMarkdownDocument {
    init(presentation: SupportedMarkdownEditorPresentation) {
        self.init(blocks: presentation.blocks.map(Self.markdownBlock))
    }

    private static func markdownBlock(
        _ block: SupportedMarkdownPresentationBlock
    ) -> SupportedMarkdownBlock {
        switch block {
        case .paragraph(let inline):
            .paragraph(text: markdownInline(inline))
        case .heading(let level, let inline):
            .heading(level: level, text: markdownInline(inline))
        case .bulletList(let items):
            .bulletList(items: items.map(markdownInline))
        case .checklist(let items):
            .checklist(items: items.map { item in
                SupportedMarkdownChecklistItem(
                    isChecked: item.isChecked,
                    text: markdownInline(item.inline)
                )
            })
        case .numberedList(let start, let items):
            .numberedList(start: start, items: items.map(markdownInline))
        case .blockQuote(let inline):
            .blockQuote(text: markdownInline(inline))
        case .divider:
            .divider
        case .fencedCodeBlock(let language, let code):
            .fencedCodeBlock(language: language, code: code)
        case .table(let table):
            .table(table)
        }
    }

    private static func markdownInline(
        _ inline: [SupportedMarkdownPresentationInline]
    ) -> [SupportedMarkdownInline] {
        inline.map { SupportedMarkdownInline(text: $0.text, styles: $0.styles) }
    }
}

public struct SupportedMarkdownEditorContent: Equatable, Sendable {
    public let text: String
    public let protectedBlocks: [SupportedMarkdownEditorProtectedBlock]

    public init(text: String, protectedBlocks: [SupportedMarkdownEditorProtectedBlock] = []) {
        self.text = text
        self.protectedBlocks = protectedBlocks
    }

    public init(presentation: SupportedMarkdownEditorPresentation) {
        var text = ""
        var protectedBlocks: [SupportedMarkdownEditorProtectedBlock] = []

        for (offset, block) in presentation.blocks.enumerated() {
            if offset > 0 {
                text.append("\n\n")
            }

            let start = (text as NSString).length
            text.append(Self.text(for: block))
            let length = (text as NSString).length - start

            if case .fencedCodeBlock(let language, _) = block {
                protectedBlocks.append(SupportedMarkdownEditorProtectedBlock(
                    range: SupportedMarkdownEditorTextRange(location: start, length: length),
                    kind: .fencedCodeBlock(language: language)
                ))
            }
        }

        self.text = text
        self.protectedBlocks = protectedBlocks
    }

    private static func text(for block: SupportedMarkdownPresentationBlock) -> String {
        switch block {
        case .paragraph(let inline):
            inline.map(\.text).joined()
        case .heading(_, let inline):
            inline.map(\.text).joined()
        case .bulletList(let items):
            items.map { "- " + $0.map(\.text).joined() }.joined(separator: "\n")
        case .checklist(let items):
            items.map { "- [\($0.isChecked ? "x" : " ")] " + $0.inline.map(\.text).joined() }.joined(separator: "\n")
        case .numberedList(let start, let items):
            items.enumerated()
                .map { offset, item in "\(start + offset). " + item.map(\.text).joined() }
                .joined(separator: "\n")
        case .blockQuote(let inline):
            inline.map(\.text).joined()
        case .divider:
            "---"
        case .fencedCodeBlock(_, let code):
            code
        case .table(let table):
            table.markdown()
        }
    }
}

public struct SupportedMarkdownEditorProtectedBlock: Equatable, Sendable {
    public let range: SupportedMarkdownEditorTextRange
    public let kind: SupportedMarkdownEditorProtectedBlockKind

    public init(range: SupportedMarkdownEditorTextRange, kind: SupportedMarkdownEditorProtectedBlockKind) {
        self.range = range
        self.kind = kind
    }
}

public enum SupportedMarkdownEditorProtectedBlockKind: Equatable, Sendable {
    case fencedCodeBlock(language: String?)
}

public struct SupportedMarkdownEditorTextRange: Equatable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }

    public func contains(_ location: Int) -> Bool {
        location >= self.location && location < self.location + length
    }
}

public enum SupportedMarkdownPresentationBlock: Equatable, Sendable {
    case paragraph(inline: [SupportedMarkdownPresentationInline])
    case heading(level: Int, inline: [SupportedMarkdownPresentationInline])
    case bulletList(items: [[SupportedMarkdownPresentationInline]])
    case checklist(items: [SupportedMarkdownPresentationChecklistItem])
    case numberedList(start: Int, items: [[SupportedMarkdownPresentationInline]])
    case blockQuote(inline: [SupportedMarkdownPresentationInline])
    case divider
    case fencedCodeBlock(language: String?, code: String)
    case table(SupportedMarkdownTable)
}

public struct SupportedMarkdownPresentationChecklistItem: Equatable, Sendable {
    public let isChecked: Bool
    public let inline: [SupportedMarkdownPresentationInline]

    public init(isChecked: Bool, inline: [SupportedMarkdownPresentationInline]) {
        self.isChecked = isChecked
        self.inline = inline
    }
}

public struct SupportedMarkdownPresentationInline: Equatable, Sendable {
    public let text: String
    public let styles: Set<SupportedMarkdownInlineStyle>

    public init(text: String, styles: Set<SupportedMarkdownInlineStyle> = []) {
        self.text = text
        self.styles = styles
    }

    public static func plain(_ text: String) -> SupportedMarkdownPresentationInline {
        SupportedMarkdownPresentationInline(text: text)
    }
}

public struct SupportedMarkdownChecklistItem: Equatable, Sendable {
    public let isChecked: Bool
    public let text: [SupportedMarkdownInline]

    public init(isChecked: Bool, text: [SupportedMarkdownInline]) {
        self.isChecked = isChecked
        self.text = text
    }
}

public struct SupportedMarkdownTable: Equatable, Sendable {
    public let header: [String]
    public let rows: [[String]]

    public init(header: [String], rows: [[String]]) {
        self.header = header
        self.rows = rows
    }

    public func markdown() -> String {
        let headerLine = tableRow(header)
        let separatorLine = tableRow(Array(repeating: "---", count: header.count))
        let rowLines = rows.map(tableRow)
        return ([headerLine, separatorLine] + rowLines).joined(separator: "\n")
    }

    private func tableRow(_ cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }
}

public struct SupportedMarkdownInline: Equatable, Sendable {
    public let text: String
    public let styles: Set<SupportedMarkdownInlineStyle>

    public init(text: String, styles: Set<SupportedMarkdownInlineStyle> = []) {
        self.text = text
        self.styles = styles
    }

    public static func plain(_ text: String) -> SupportedMarkdownInline {
        SupportedMarkdownInline(text: text)
    }
}

public enum SupportedMarkdownInlineStyle: String, Hashable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case inlineCode
}

private extension Array where Element == SupportedMarkdownInline {
    func markdown() -> String {
        map { $0.markdown() }.joined()
    }
}

private extension SupportedMarkdownInline {
    func markdown() -> String {
        var rendered = SupportedMarkdownEscaping.escapeInlineText(text)
        if styles.contains(.inlineCode) {
            rendered = "`\(rendered)`"
        }
        if styles.contains(.strikethrough) {
            rendered = "~~\(rendered)~~"
        }
        if styles.contains(.underline) {
            rendered = "<u>\(rendered)</u>"
        }
        if styles.contains(.italic) {
            rendered = "*\(rendered)*"
        }
        if styles.contains(.bold) {
            rendered = "**\(rendered)**"
        }
        return rendered
    }
}

private enum SupportedMarkdownEscaping {
    static func escapeInlineText(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "\\", "*", "~", "`", "<":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }
        return escaped
    }

    static func escapeParagraphBlockMarkers(_ markdown: String) -> String {
        markdown
            .components(separatedBy: "\n")
            .map { line in
                shouldEscapeParagraphLine(line) ? "\\\(line)" : line
            }
            .joined(separator: "\n")
    }

    private static func shouldEscapeParagraphLine(_ line: String) -> Bool {
        line.hasPrefix("# ")
            || line.hasPrefix("## ")
            || line.hasPrefix("### ")
            || line.hasPrefix("> ")
            || line.hasPrefix("- ")
            || isNumberedListLine(line)
            || line == "---"
            || isTableRowLine(line)
    }

    private static func isNumberedListLine(_ line: String) -> Bool {
        let digits = line.prefix { $0.isNumber }
        return !digits.isEmpty && line.dropFirst(digits.count).hasPrefix(". ")
    }

    private static func isTableRowLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }
}
