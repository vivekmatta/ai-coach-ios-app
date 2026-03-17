import Foundation

// MARK: – Gemini REST API Service
// Calls https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent
// API key is stored in UserDefaults (set at first launch via settings or hardcoded for dev).
// For production, move key to iOS Keychain.

actor GeminiService {
    static let shared = GeminiService()
    private init() {}

    // API key priority:
    // 1. UserDefaults (set at runtime via Profile & Settings screen)
    // 2. GEMINI_API_KEY Xcode scheme environment variable (never committed to git)
    //    Set via: Xcode → Edit Scheme → Run → Arguments → Environment Variables
    // Get a key at: https://aistudio.google.com/app/apikey
    private var apiKey: String {
        if let key = UserDefaults.standard.string(forKey: "geminiAPIKey"), !key.isEmpty {
            return key
        }
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }

    private let model = "gemini-2.5-flash"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // MARK: – Request / Response types
    private struct Part: Codable { let text: String }
    private struct Content: Codable { let role: String; let parts: [Part] }
    private struct SystemInstruction: Codable { let parts: [Part] }
    private struct GenerationConfig: Codable {
        let temperature: Double
        let maxOutputTokens: Int
    }
    private struct RequestBody: Codable {
        let systemInstruction: SystemInstruction
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct ResponseCandidate: Codable {
        struct Content: Codable { let parts: [Part] }
        let content: Content?
    }
    private struct ResponseBody: Codable {
        let candidates: [ResponseCandidate]?
        let error: ResponseError?
    }
    private struct ResponseError: Codable {
        let message: String
    }

    // MARK: – Public API
    /// Send a chat message and get a response back.
    /// - Parameters:
    ///   - systemPrompt: Full system instruction string.
    ///   - history: Previous turn pairs (user/model).
    ///   - userMessage: The new user message.
    func send(systemPrompt: String,
              history: [ChatMessage],
              userMessage: String) async throws -> String {

        let key = apiKey
        guard !key.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let urlString = "\(baseURL)/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        // Build contents array from history + new message
        var contents: [Content] = history.compactMap { msg in
            guard !msg.isTyping else { return nil }
            return Content(role: msg.role.rawValue, parts: [Part(text: msg.text)])
        }
        contents.append(Content(role: "user", parts: [Part(text: userMessage)]))

        let body = RequestBody(
            systemInstruction: SystemInstruction(parts: [Part(text: systemPrompt)]),
            contents: contents,
            generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 2048)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)

        if let error = decoded.error {
            throw GeminiError.apiError(error.message)
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        guard let text = decoded.candidates?.first?.content?.parts.first?.text else {
            throw GeminiError.emptyResponse
        }

        return text
    }

    // Convenience: set API key at runtime (e.g., from a settings screen)
    nonisolated func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "geminiAPIKey")
    }
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "Gemini API key not set. Add your key in Settings."
        case .invalidURL:        return "Invalid API URL."
        case .invalidResponse:   return "Invalid server response."
        case .httpError(let c):  return "HTTP error \(c)."
        case .apiError(let m):   return "API error: \(m)"
        case .emptyResponse:     return "Empty response from Gemini."
        }
    }
}
