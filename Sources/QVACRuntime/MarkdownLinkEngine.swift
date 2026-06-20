import Foundation

struct WikilinkOccurrence {
    let title: String
    let snippet: String
    let createsPlaceholder: Bool
    let position: String.Index
    let markdownTargetPath: String?
}

struct MarkdownLinkEngine {
    func wikilinks(in body: String) -> [WikilinkOccurrence] {
        var occurrences: [WikilinkOccurrence] = []
        var searchStart = body.startIndex

        while let opening = body.range(of: "[[", range: searchStart..<body.endIndex) {
            if opening.lowerBound > body.startIndex, body[body.index(before: opening.lowerBound)] == "!" {
                searchStart = opening.upperBound
                continue
            }

            guard let closing = body.range(of: "]]", range: opening.upperBound..<body.endIndex) else {
                break
            }

            let title = String(body[opening.upperBound..<closing.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !title.isEmpty {
                occurrences.append(WikilinkOccurrence(
                    title: title,
                    snippet: lineSnippet(in: body, containing: opening.lowerBound..<closing.upperBound),
                    createsPlaceholder: true,
                    position: opening.lowerBound,
                    markdownTargetPath: nil
                ))
            }

            searchStart = closing.upperBound
        }

        return occurrences
    }

    func importedLinks(in body: String) -> [WikilinkOccurrence] {
        (wikilinks(in: body) + markdownLinks(in: body)).sorted { $0.position < $1.position }
    }

    private func markdownLinks(in body: String) -> [WikilinkOccurrence] {
        var occurrences: [WikilinkOccurrence] = []
        var searchStart = body.startIndex

        while let opening = body.range(of: "[", range: searchStart..<body.endIndex) {
            if opening.lowerBound > body.startIndex, body[body.index(before: opening.lowerBound)] == "!" {
                searchStart = opening.upperBound
                continue
            }
            if opening.upperBound < body.endIndex, body[opening.upperBound] == "[" {
                searchStart = opening.upperBound
                continue
            }
            guard let closingLabel = body.range(of: "]", range: opening.upperBound..<body.endIndex) else {
                break
            }
            guard closingLabel.upperBound < body.endIndex, body[closingLabel.upperBound] == "(" else {
                searchStart = closingLabel.upperBound
                continue
            }
            let targetStart = body.index(after: closingLabel.upperBound)
            guard let closingTarget = body.range(of: ")", range: targetStart..<body.endIndex) else {
                break
            }
            let target = String(body[targetStart..<closingTarget.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let title = markdownTitle(from: target) {
                occurrences.append(WikilinkOccurrence(
                    title: title,
                    snippet: lineSnippet(in: body, containing: opening.lowerBound..<closingTarget.upperBound),
                    createsPlaceholder: true,
                    position: opening.lowerBound,
                    markdownTargetPath: markdownPath(from: target)
                ))
            }

            searchStart = closingTarget.upperBound
        }

        return occurrences
    }

    private func markdownTitle(from target: String) -> String? {
        guard let path = markdownPath(from: target),
              let fileName = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last else {
            return nil
        }
        let title = String(fileName)
        if title.lowercased().hasSuffix(".md") {
            return String(title.dropLast(3))
        }

        return title.isEmpty ? nil : title
    }

    private func markdownPath(from target: String) -> String? {
        guard !target.isEmpty, !target.contains("://"), !target.hasPrefix("#") else {
            return nil
        }

        let withoutFragment = target.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let withoutQuery = withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let path = String(withoutQuery)
        return path.isEmpty ? nil : path
    }

    private func lineSnippet(in body: String, containing range: Range<String.Index>) -> String {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        while lowerBound > body.startIndex {
            let previous = body.index(before: lowerBound)
            if body[previous] == "\n" {
                break
            }
            lowerBound = previous
        }

        while upperBound < body.endIndex {
            if body[upperBound] == "\n" {
                break
            }
            upperBound = body.index(after: upperBound)
        }

        return String(body[lowerBound..<upperBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
