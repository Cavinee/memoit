import Foundation

public enum UserCreatedNoteDraftDiscardPolicy {
    public static func shouldDiscard(title: String, body: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
