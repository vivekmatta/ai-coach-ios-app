import Foundation

#if canImport(FirebaseAILogic)
import FirebaseAILogic
#elseif canImport(FirebaseAI)
import FirebaseAI
#endif

enum AICoachServiceError: LocalizedError {
    case firebaseUnavailable
    case firebaseConfigMissing
    case proxyUnavailable
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase AI Logic is not linked yet."
        case .firebaseConfigMissing:
            return "GoogleService-Info.plist is missing from the app bundle."
        case .proxyUnavailable:
            return "Local AI proxy is not reachable."
        case .emptyResponse:
            return "AI returned an empty response."
        case .invalidJSON:
            return "AI returned JSON the app could not read."
        }
    }
}

final class AICoachService {
    static let shared = AICoachService()

    private let decoder = JSONDecoder()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func analyze(syncId: String, contextJSON: String) async throws -> AICoachAnalysis {
        do {
            return try await analyzeWithFirebase(syncId: syncId, contextJSON: contextJSON)
        } catch {
            do {
                return try await analyzeWithProxy(syncId: syncId, contextJSON: contextJSON)
            } catch {
                throw error
            }
        }
    }

    private func analyzeWithFirebase(syncId: String, contextJSON: String) async throws -> AICoachAnalysis {
#if canImport(FirebaseAILogic) || canImport(FirebaseAI)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            throw AICoachServiceError.firebaseConfigMissing
        }

        let prompt = Self.prompt(syncId: syncId, contextJSON: contextJSON)
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash",
            generationConfig: GenerationConfig(responseMIMEType: "application/json")
        )
        let response = try await model.generateContent(prompt)
        guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICoachServiceError.emptyResponse
        }
        guard let data = text.data(using: .utf8),
              let decoded = try? decoder.decode(AICoachAnalysis.self, from: data) else {
            throw AICoachServiceError.invalidJSON
        }
        return AICoachAnalysis(
            syncId: decoded.syncId.isEmpty ? syncId : decoded.syncId,
            generatedAt: decoded.generatedAt.isEmpty ? isoFormatter.string(from: Date()) : decoded.generatedAt,
            overallSummary: decoded.overallSummary,
            priority: decoded.priority,
            metricExplanations: decoded.metricExplanations,
            insightCards: decoded.insightCards,
            warnings: decoded.warnings,
            source: "firebase_ai_logic"
        )
#else
        throw AICoachServiceError.firebaseUnavailable
#endif
    }

    private func analyzeWithProxy(syncId: String, contextJSON: String) async throws -> AICoachAnalysis {
        let rawURL = UserDefaults.standard.string(forKey: "WatchProbe.localAIProxyURL") ?? ""
        let trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              var components = URLComponents(string: trimmedURL) else {
            throw AICoachServiceError.proxyUnavailable
        }
        components.path = "/analyze"
        guard let url = components.url else {
            throw AICoachServiceError.proxyUnavailable
        }

        let payload = [
            "syncId": syncId,
            "contextJSON": contextJSON
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AICoachServiceError.proxyUnavailable
        }
        guard let decoded = try? decoder.decode(AICoachAnalysis.self, from: data) else {
            throw AICoachServiceError.invalidJSON
        }
        return AICoachAnalysis(
            syncId: decoded.syncId.isEmpty ? syncId : decoded.syncId,
            generatedAt: decoded.generatedAt.isEmpty ? isoFormatter.string(from: Date()) : decoded.generatedAt,
            overallSummary: decoded.overallSummary,
            priority: decoded.priority,
            metricExplanations: decoded.metricExplanations,
            insightCards: decoded.insightCards,
            warnings: decoded.warnings,
            source: "local_gemini_proxy"
        )
    }

    private static func prompt(syncId: String, contextJSON: String) -> String {
        """
        You are AI Coach, a concise, practical health and recovery coach for watch data.

        Your job:
        - Explain the user's synced watch data in plain English.
        - Be specific about what the data suggests, but separate observations from uncertainty.
        - Never diagnose, prescribe, or imply medical certainty.
        - Never recommend medication changes.
        - Encourage rechecking unusual values and seeking qualified care for concerning symptoms.
        - Prefer simple next actions: sync consistency, sleep timing, recovery, hydration, movement, and follow-up measurements.
        - Mention missing, stale, skipped, or unreliable data when it affects confidence.
        - Correlate metrics only when the input has timestamp overlap or directly comparable trend windows.
        - Use timeCorrelations.sleepWindows and timeCorrelations.heartRateSamples to decide whether a heart-rate sample happened during sleep.
        - If timestamps are missing or do not overlap, say the relationship is unclear instead of inventing a connection.
        - Do not explain a number in isolation when nearby sleep, activity, oxygen, temperature, or HRV data gives better context.
        - Prefer statements like "during the recorded sleep window" or "outside the sleep window" only when insideSleepWindow is true or false in the provided samples.
        - Use the adult reference context below only as educational context, not as a diagnosis.
        - Do not apply pediatric ranges unless the app explicitly provides a child age/profile.
        - For values outside common adult ranges, suggest rechecking the measurement and contacting a qualified clinician when concerned, symptomatic, or readings are repeated.
        - Keep the tone direct, calm, and useful.

        Adult reference context for common vitals:
        - Blood pressure: AHA adult categories classify normal as systolic under 120 and diastolic under 80 mmHg; elevated as 120-129 and under 80; stage 1 as 130-139 or 80-89; stage 2 as 140+ or 90+. Repeated measurements matter.
        - Blood oxygen: FDA and MedlinePlus describe 95-100% SpO2 as typical for most healthy people. Altitude and heart/lung conditions can affect this.
        - Resting heart rate: AHA describes 60-100 bpm as the normal average resting adult range. Athletes can be lower; activity, stress, sleep, illness, and stimulants matter.

        Return JSON only. Do not wrap it in markdown.

        Required JSON shape:
        {
          "syncId": "\(syncId)",
          "generatedAt": "ISO-8601 timestamp",
          "overallSummary": "1-2 sentence summary",
          "priority": "single most useful next action",
          "metricExplanations": {
            "sleep": {
              "metricId": "sleep",
              "shortExplanation": "1-2 sentences",
              "details": "more context",
              "confidence": "low|medium|high",
              "dataQuality": "missing|partial|available|stale|unreliable"
            }
          },
          "insightCards": [
            {
              "id": "stable-id",
              "title": "short title",
              "body": "1-2 sentence coach insight",
              "metricIds": ["sleep"],
              "priority": 1
            }
          ],
          "warnings": ["brief non-diagnostic safety or data-quality note"],
          "source": "firebase_ai_logic"
        }

        Include metricExplanations for every metric present in the input. Use the same metricId values.
        In insightCards, prioritize cross-metric observations supported by the timeCorrelations object.
        If the evidence is weak, make a data-quality insight instead of a health conclusion.

        Watch data context:
        \(contextJSON)
        """
    }
}
