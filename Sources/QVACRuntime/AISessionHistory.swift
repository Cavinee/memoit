import Foundation

public struct AISessionHistoryEntryID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public struct AISessionHistoryEntry: Equatable, Sendable {
    public let id: AISessionHistoryEntryID
    public let prompt: String
    public let response: String
    public let mode: AnswerMode
    public let createdAt: Date
    public let citations: [SourceCitation]

    public init(
        id: AISessionHistoryEntryID,
        prompt: String,
        response: String,
        mode: AnswerMode,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        citations: [SourceCitation] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.response = response
        self.mode = mode
        self.createdAt = createdAt
        self.citations = citations
    }
}

final class AISessionHistoryStore {
    private var entries: [AISessionHistoryEntry] = []
    private var nextEntryNumber = 1

    func record(
        prompt: String,
        response: String,
        mode: AnswerMode,
        createdAt: Date,
        citations: [SourceCitation]
    ) -> AISessionHistoryEntry {
        let entry = AISessionHistoryEntry(
            id: .init("ai-session-history-\(nextEntryNumber)"),
            prompt: prompt,
            response: response,
            mode: mode,
            createdAt: createdAt,
            citations: citations
        )
        nextEntryNumber += 1
        entries.append(entry)
        return entry
    }

    func list() -> [AISessionHistoryEntry] {
        entries
    }

    func delete(entryID: AISessionHistoryEntryID) throws -> AISessionHistoryEntryID {
        guard entries.contains(where: { $0.id == entryID }) else {
            throw RuntimeError.aiSessionHistoryEntryNotFound(entryID)
        }

        entries.removeAll { $0.id == entryID }
        return entryID
    }
}
