import Foundation

public struct NoteID: Hashable, Equatable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }
}

public enum CreationProvenance: String, Equatable, Sendable {
    case userCreated = "user-created"
    case imported
    case placeholderCreated = "placeholder-created"
    case aiCreated = "ai-created"
}

public struct ImportProvenance: Equatable, Sendable {
    public let sourcePath: String

    public init(sourcePath: String) {
        self.sourcePath = sourcePath
    }
}

public struct Note: Equatable, Sendable {
    public let id: NoteID
    public let title: String
    public let body: String
    public let creationProvenance: CreationProvenance
    public let importProvenance: ImportProvenance?
    public let isPlaceholder: Bool
    public let isTrashed: Bool
    public let isPinned: Bool
    public let lastEditedAt: Date

    public init(
        id: NoteID,
        title: String,
        body: String,
        creationProvenance: CreationProvenance,
        importProvenance: ImportProvenance? = nil,
        isPlaceholder: Bool = false,
        isTrashed: Bool = false,
        isPinned: Bool = false,
        lastEditedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.creationProvenance = creationProvenance
        self.importProvenance = importProvenance
        self.isPlaceholder = isPlaceholder
        self.isTrashed = isTrashed
        self.isPinned = isPinned
        self.lastEditedAt = lastEditedAt
    }
}
