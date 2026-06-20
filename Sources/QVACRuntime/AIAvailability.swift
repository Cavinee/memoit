public enum AIUnavailableState: Equatable, Sendable {
    case noUsableLocalModelProfile
}

public enum AIProgressState: Equatable, Codable, Sendable {
    case idle
    case loadingModel
    case generating
}
