struct TitleDisambiguator {
    func disambiguatedTitle(requestedTitle: String, existingTitles: Set<String>) -> String {
        var candidate = requestedTitle
        var suffix = 2

        while existingTitles.contains(candidate) {
            candidate = "\(requestedTitle) (\(suffix))"
            suffix += 1
        }

        return candidate
    }
}
