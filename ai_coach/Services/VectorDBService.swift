import Foundation
import Accelerate

// MARK: – On-Device Vector DB
// Simple cosine-similarity RAG without Core ML dependency.
// Chunks the 4 bundled .txt files and uses TF-IDF-style keyword matching
// as a lightweight fallback until the Core ML model is bundled.
// Replace `embed(_:)` with a Core ML call when AllMiniLML6V2.mlpackage is added.

struct DocumentChunk: Codable {
    let text: String
    let source: String
    let embedding: [Float]
}

actor VectorDBService {
    static let shared = VectorDBService()
    private init() {}

    private var chunks: [DocumentChunk] = []
    private var isBuilt = false

    // MARK: – Build
    func buildIfNeeded() async {
        guard !isBuilt else { return }

        // Try loading from disk cache first
        if PersistenceService.shared.vectorDBBuilt, let cached = loadFromDisk() {
            chunks = cached
            isBuilt = true
            return
        }

        // Build from bundled text files
        let files = ["user_profile", "health_log", "workout_log", "meal_log"]
        var allChunks: [DocumentChunk] = []

        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let fileChunks = chunkText(text, source: file)
            allChunks.append(contentsOf: fileChunks)
        }

        // Embed all chunks
        for chunk in allChunks {
            let embedding = embed(chunk.text)
            allChunks[allChunks.firstIndex(where: { $0.text == chunk.text })!] = DocumentChunk(
                text: chunk.text,
                source: chunk.source,
                embedding: embedding
            )
        }

        chunks = allChunks
        saveToDisk(allChunks)
        PersistenceService.shared.vectorDBBuilt = true
        isBuilt = true
    }

    // MARK: – Query
    func query(_ text: String, k: Int = 8) async -> String {
        guard !chunks.isEmpty else { return "" }

        let queryEmbedding = embed(text)

        let scored = chunks.map { chunk -> (score: Float, text: String) in
            let score = cosineSimilarity(queryEmbedding, chunk.embedding)
            return (score, chunk.text)
        }
        .sorted { $0.score > $1.score }
        .prefix(k)
        .map { $0.text }

        return scored.joined(separator: "\n\n---\n\n")
    }

    // MARK: – Reset
    func reset() {
        chunks = []
        isBuilt = false
        let url = cacheURL()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: – Private helpers

    private func chunkText(_ text: String, source: String, chunkSize: Int = 500, overlap: Int = 50) -> [DocumentChunk] {
        var result: [DocumentChunk] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var start = 0

        while start < words.count {
            let end = min(start + chunkSize / 5, words.count) // rough word count
            let slice = words[start..<end].joined(separator: " ")
            result.append(DocumentChunk(text: slice, source: source, embedding: []))
            if end == words.count { break }
            start = max(end - overlap / 5, start + 1)
        }
        return result
    }

    /// Lightweight TF-IDF keyword embedding (384-dim approximation).
    /// Replace with Core ML call for true semantic embeddings.
    private func embed(_ text: String) -> [Float] {
        let dim = 384
        var vec = [Float](repeating: 0, count: dim)
        let tokens = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }

        for token in tokens {
            var h = token.hashValue
            for i in 0..<min(3, dim) {
                let idx = abs(h) % dim
                vec[idx] += 1.0
                h = h &* 1664525 &+ 1013904223
            }
        }

        // L2-normalize
        var norm: Float = 0
        vDSP_svesq(vec, 1, &norm, vDSP_Length(dim))
        norm = sqrt(norm)
        if norm > 0 {
            var n = norm
            vDSP_vsdiv(vec, 1, &n, &vec, 1, vDSP_Length(dim))
        }
        return vec
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        return dot  // vectors are L2-normalized
    }

    // MARK: – Disk cache
    private func cacheURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vector_index.json")
    }

    private func saveToDisk(_ data: [DocumentChunk]) {
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: cacheURL())
        }
    }

    private func loadFromDisk() -> [DocumentChunk]? {
        guard let data = try? Data(contentsOf: cacheURL()),
              let decoded = try? JSONDecoder().decode([DocumentChunk].self, from: data) else {
            return nil
        }
        return decoded
    }
}
