import Foundation

/// In-memory semantic index over Note embeddings. Holds one vector per Note and
/// returns the Notes most similar to a query vector by cosine similarity, above a
/// caller-supplied threshold. Pure Swift (no SDK dependency) so the ranking and
/// threshold logic is unit-testable off-device.
final class NoteEmbeddingIndex {
    private struct Record {
        let noteID: NoteID
        let vector: [Float]
        let norm: Float
    }

    private var records: [Record] = []

    /// Whether the embedding index has been built at least once. Retrieval gates
    /// semantic search on this so that, during first-run backfill (provider set but
    /// no embedding rebuild yet), the runtime falls back to the lexical index instead
    /// of returning nothing.
    private(set) var isReady = false

    func rebuild(from notes: [Note], provider: NoteEmbeddingProvider) throws {
        try rebuild(from: notes, provider: provider, store: nil, modelID: provider.modelID)
    }

    /// Rebuilds the in-memory index. With `store == nil` every note is embedded (the
    /// in-memory path). With a `store`, an unchanged note (matching `modelID` AND
    /// `contentHash`) reuses its persisted vector instead of re-embedding; new/changed
    /// notes are embedded and upserted; rows for notes no longer present are dropped.
    func rebuild(from notes: [Note], provider: NoteEmbeddingProvider, store: (any NoteEmbeddingStore)?, modelID: String) throws {
        guard let store else {
            records = try notes.map { note in
                let vector = try provider.embed(Self.embeddingInput(for: note))
                return Record(noteID: note.id, vector: vector, norm: Self.norm(vector))
            }
            isReady = true
            return
        }

        let stored = try store.loadAll()
        var newRecords: [Record] = []
        newRecords.reserveCapacity(notes.count)

        for note in notes {
            let contentHash = Self.contentHash(for: note)
            let vector: [Float]
            if let existing = stored[note.id], existing.modelID == modelID, existing.contentHash == contentHash {
                vector = existing.vector
            } else {
                vector = try provider.embed(Self.embeddingInput(for: note))
                try store.upsert(StoredNoteEmbedding(
                    noteID: note.id,
                    modelID: modelID,
                    contentHash: contentHash,
                    vector: vector
                ))
            }
            newRecords.append(Record(noteID: note.id, vector: vector, norm: Self.norm(vector)))
        }

        try store.deleteAll(exceptNoteIDs: Set(notes.map(\.id)))
        records = newRecords
        isReady = true
    }

    private static func embeddingInput(for note: Note) -> String {
        "\(note.title)\n\(note.body)"
    }

    /// Stable, process-independent FNV-1a hash of the embedded content. A mismatch with
    /// the stored hash means the note's title/body changed and it must be re-embedded.
    /// Deliberately NOT Swift's `Hasher` (per-process seeded → never stable across runs).
    private static func contentHash(for note: Note) -> String {
        var hash: UInt64 = 1469598103934665603 // FNV-1a 64-bit offset basis
        for byte in embeddingInput(for: note).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211 // FNV-1a 64-bit prime
        }
        return String(hash, radix: 16)
    }

    /// Note IDs whose embedding cosine-similarity to `queryVector` is at least
    /// `threshold`, most-similar first, capped to `topK`.
    func search(queryVector: [Float], topK: Int, threshold: Float) -> [NoteID] {
        let queryNorm = Self.norm(queryVector)
        guard queryNorm > 0 else { return [] }

        let scored: [(noteID: NoteID, score: Float)] = records.compactMap { record in
            guard record.norm > 0 else { return nil }
            let score = Self.dot(record.vector, queryVector) / (record.norm * queryNorm)
            return score >= threshold ? (record.noteID, score) : nil
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0.noteID }
    }

    private static func dot(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        var sum: Float = 0
        for i in 0..<count {
            sum += a[i] * b[i]
        }
        return sum
    }

    private static func norm(_ vector: [Float]) -> Float {
        var sum: Float = 0
        for value in vector {
            sum += value * value
        }
        return sum.squareRoot()
    }
}
