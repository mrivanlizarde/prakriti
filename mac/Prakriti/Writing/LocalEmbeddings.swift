import Foundation

// The embeddings that find moments from another recording (v2 part M12a, docs/v2/PLAN.md M12, design spec 3.8): LM Studio's
// `text-embedding-nomic-embed-text-v1.5` through its OpenAI-compatible `/v1/embeddings`, on this Mac and nowhere else. Text, not
// biometrics: the words of a transcript, never a face or a voice.
//
// The request shape was checked against LM Studio on the build day (Fri 16 Oct 2026): `POST http://localhost:1235/v1/embeddings` with
// `{"model": "...", "input": ["...", "..."]}` answers `{"object": "list", "data": [{"object": "embedding", "embedding": [768 numbers],
// "index": 0}, ...], "model": "...", "usage": {...}}`; 64 inputs of about 60 words took 0.61 s. nomic-embed-text-v1.5 is trained with a
// task prefix on every text: "search_document: " for what is searched, "search_query: " for what is searched for.
//
// This is the only way `Merge/` reaches a model's embeddings (PLAN 2.2 rule 2): it refuses, before anything is sent, any address
// whose host is not this Mac (`localhost`, `127.0.0.1`, `::1`), so a changed LM Studio address can never carry a transcript off it.

/// What `Merge/` asks for: numbers for each text, in order, each of length 1.
protocol MomentEmbedder: Sendable {
    /// The model's id, kept with the index so vectors from another model are never compared with these.
    var modelID: String { get }
    /// Who does it, for the log ("nomic-embed-text-v1.5 in LM Studio").
    var displayName: String { get }
    func embed(_ texts: [String]) async throws -> [[Float]]
}

struct EmbeddingFailure: Error, Equatable, Sendable {
    let reason: String
}

struct LocalEmbeddings: MomentEmbedder {
    nonisolated static let defaultModel = "text-embedding-nomic-embed-text-v1.5"
    /// nomic-embed-text-v1.5's task prefixes.
    nonisolated static let documentPrefix = "search_document: "
    nonisolated static let queryPrefix = "search_query: "
    /// Inputs per request.
    nonisolated static let batch = 48

    let address: URL
    let modelID: String
    let session: URLSession

    var displayName: String { modelID.replacingOccurrences(of: "text-embedding-", with: "") + " in LM Studio" }

    /// The host is this Mac, or nothing is ever sent.
    static func isThisMac(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", let host = url.host()?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
    }

    /// `address` is LM Studio's OpenAI-compatible root ("http://localhost:1235/v1"). Refuses any other host.
    init(address: String, model: String = LocalEmbeddings.defaultModel, session: URLSession = ModelHTTP.session) throws {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed), Self.isThisMac(url) else {
            throw EmbeddingFailure(reason: "The LM Studio address is not on this Mac, so nothing was sent. Moments are found only on this Mac.")
        }
        self.address = url
        self.modelID = model
        self.session = session
    }

    func embed(_ texts: [String]) async throws -> [[Float]] {
        var out: [[Float]] = []
        var start = 0
        while start < texts.count {
            let part = Array(texts[start..<min(texts.count, start + Self.batch)])
            out += try await request(part)
            start += part.count
        }
        return out
    }

    private func request(_ texts: [String]) async throws -> [[Float]] {
        let url = address.appending(path: "embeddings")
        guard Self.isThisMac(url) else { throw EmbeddingFailure(reason: "The LM Studio address is not on this Mac, so nothing was sent.") }
        let (status, data) = try await ModelHTTP.send(ModelHTTP.post(url, body: ["model": modelID, "input": texts]), session: session, service: "LM Studio")
        guard status == 200, let object = ModelHTTP.object(data), let rows = object["data"] as? [[String: Any]] else {
            throw EmbeddingFailure(reason: "LM Studio did not give the numbers for the transcript (\(status) \(ModelHTTP.errorText(data))). "
                                   + "Check that \(Self.defaultModel) is downloaded in LM Studio.")
        }
        var vectors = [[Float]](repeating: [], count: texts.count)
        for row in rows {
            guard let index = row["index"] as? Int, vectors.indices.contains(index), let numbers = row["embedding"] as? [Double], !numbers.isEmpty else { continue }
            vectors[index] = Self.unit(numbers.map(Float.init))
        }
        guard vectors.allSatisfy({ !$0.isEmpty }), Set(vectors.map(\.count)).count == 1 else {
            throw EmbeddingFailure(reason: "LM Studio's answer did not hold one set of numbers for every text.")
        }
        return vectors
    }

    /// Scaled to length 1, so a dot product is the cosine.
    static func unit(_ v: [Float]) -> [Float] {
        let length = (v.reduce(Float(0)) { $0 + $1 * $1 }).squareRoot()
        return length > 0 ? v.map { $0 / length } : v
    }
}
