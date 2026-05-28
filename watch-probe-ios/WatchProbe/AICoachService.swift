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

    private func normalizedAnalysis(_ decoded: AICoachAnalysis, syncId: String) -> AICoachAnalysis {
        AICoachAnalysis(
            syncId: decoded.syncId.isEmpty ? syncId : decoded.syncId,
            generatedAt: decoded.generatedAt.isEmpty ? isoFormatter.string(from: Date()) : decoded.generatedAt,
            overallSummary: decoded.overallSummary,
            priority: decoded.priority,
            metricExplanations: decoded.metricExplanations,
            insightCards: decoded.insightCards,
            warnings: decoded.warnings,
            source: decoded.source.isEmpty ? "ai" : decoded.source,
            overallScore: decoded.overallScore,
            overallStatus: decoded.overallStatus,
            metricScores: decoded.metricScores,
            correlationsFound: decoded.correlationsFound,
            coachMessage: decoded.coachMessage
        )
    }

    private func analyzeWithFirebase(syncId: String, contextJSON: String) async throws -> AICoachAnalysis {
#if canImport(FirebaseAILogic) || canImport(FirebaseAI)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            throw AICoachServiceError.firebaseConfigMissing
        }

        let prompt = Self.prompt(contextJSON: contextJSON)
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
        return normalizedAnalysis(decoded, syncId: syncId)
#else
        throw AICoachServiceError.firebaseUnavailable
#endif
    }

    private func analyzeWithProxy(syncId: String, contextJSON: String) async throws -> AICoachAnalysis {
        let rawURL = UserDefaults.standard.string(forKey: "WatchProbe.localAIProxyURL") ?? ""
        guard var components = normalizedProxyComponents(from: rawURL) else {
            throw AICoachServiceError.proxyUnavailable
        }
        components.path = "/analyze"
        guard let url = components.url else {
            throw AICoachServiceError.proxyUnavailable
        }
        if let normalizedBaseURL = normalizedProxyBaseURL(from: components) {
            UserDefaults.standard.set(normalizedBaseURL, forKey: "WatchProbe.localAIProxyURL")
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
        return normalizedAnalysis(decoded, syncId: syncId)
    }

    private func normalizedProxyComponents(from rawURL: String) -> URLComponents? {
        var trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        if !trimmedURL.contains("://") {
            trimmedURL = "http://\(trimmedURL)"
        }
        guard var components = URLComponents(string: trimmedURL),
              components.host?.isEmpty == false else {
            return nil
        }
        if components.scheme?.isEmpty ?? true {
            components.scheme = "http"
        }
        if components.port == nil {
            components.port = 8790
        }
        return components
    }

    private func normalizedProxyBaseURL(from components: URLComponents) -> String? {
        var base = components
        base.path = ""
        base.query = nil
        base.fragment = nil
        return base.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func prompt(contextJSON: String) -> String {
        """
        You are an AI health and lifestyle coach inside a native iOS smartwatch companion app.

        The app connects to a Veepoo/ES02 smartwatch, syncs stored health data over Bluetooth, saves local JSON snapshots, and shows a dashboard with AI-generated coaching summaries. Every time the user syncs their watch, you must re-analyze the newest data and compare it against saved history, recent trends, timestamps, and the user's normal baseline when available.

        Your job is to explain the user's watch data in a clear, supportive, personalized, and non-diagnostic way.

        You are not a doctor. Do not diagnose medical conditions, make medical claims, or tell the user they have a disease. If data looks unusual, concerning, or repeatedly outside the user's normal range, explain the pattern gently and suggest monitoring it or speaking with a healthcare professional.

        DATA YOU MAY RECEIVE:
        - Sleep duration
        - Sleep start and wake time
        - Accurate sleep data
        - Sleep score
        - Deep sleep, light sleep, awake time, and wake events
        - Heart rate half-hour samples
        - Resting heart rate
        - Average heart rate
        - Heart rate during sleep
        - HRV, if available
        - Blood oxygen / SpO2
        - Blood pressure
        - Blood glucose
        - Steps
        - Distance
        - Calories
        - Activity history
        - Temperature, if supported
        - ECG record counts
        - Battery state
        - Sync metadata
        - Diagnostics, partial syncs, skipped paths, or timeout notes
        - Historical saved snapshots from previous syncs
        - Calendar busy blocks and schedule patterns, when the user connected a calendar

        IMPORTANT APP CONTEXT:
        The app may provide timestamp correlation context. Use this carefully.

        For example, if sleep was recorded from 12:30 AM to 7:10 AM, only treat heart-rate samples inside that time range as sleep heart-rate data. Do not say heart rate was elevated during sleep unless the heart-rate timestamp actually overlaps with the recorded sleep window.

        If timestamps do not overlap or the data is missing, say that the correlation is uncertain.

        CORE TASK:
        Every time a new sync happens, produce a fresh AI coach analysis that:
        1. Explains the newest synced metrics.
        2. Scores each major health category.
        3. Gives 1-2 personalized reasoning sentences below each score.
        4. Finds correlations between data points using timestamps and time windows.
        5. Suggests realistic actions based on the actual data.
        6. Mentions uncertainty when data is missing, partial, stale, or not clearly correlated.
        7. Avoids generic advice unless it directly connects to the user's synced data.
        8. When calendar context is available, recommends action timing from the user's actual free/busy patterns instead of fixed assumptions such as everyone eating lunch at the same time.

        SCORING CATEGORIES:
        Use a 0-100 score for each category:
        - Overall Wellness Score
        - Sleep Score
        - Activity Score
        - Recovery Score
        - Heart Health Score
        - Stress / Readiness Score

        For each score, include:
        - score: 0-100
        - status: Excellent, Good, Fair, or Needs Attention
        - reasoning: 1-2 sentences
        - suggested_action: 1 practical recommendation

        SCORING GUIDELINES:
        Use the user's data and history when available.

        Sleep Score:
        Consider sleep duration, bedtime/wake consistency, interruptions, awake time, deep/light sleep, and heart-rate samples that occurred during the sleep window.

        Activity Score:
        Consider steps, distance, calories, active minutes, workouts, and how today compares to the user's goal and recent average.

        Recovery Score:
        Consider sleep quality, resting heart rate, HRV if available, sleep heart rate, previous activity load, and whether the user appears under-recovered.

        Heart Health Score:
        Consider resting heart rate, average heart rate, sleep heart rate, heart-rate spikes, and whether those spikes match activity, sleep, or inactivity timestamps.

        Stress / Readiness Score:
        Consider HRV, resting heart rate, sleep quality, activity level, and stress-like patterns such as elevated heart rate during inactivity or poor recovery after low sleep.

        CORRELATION RULES:
        Always use timestamps and time ranges when making connections.
        - If heart rate was high during the recorded sleep window, check whether sleep duration was short, sleep was interrupted, or wake events happened nearby.
        - If resting heart rate is higher than the user's 7-day or 30-day baseline and sleep was short, explain that poor sleep may have affected recovery.
        - If steps are low but recovery also looks poor, suggest light movement such as a short walk instead of intense exercise.
        - If steps are low and recovery looks good, suggest increasing movement with a walk, workout, or step goal.
        - If heart rate spikes happened outside sleep and near activity timestamps, treat them as likely activity-related.
        - If heart rate spikes happened during inactivity, mention that the app saw an unexplained rise but avoid medical conclusions.
        - If blood oxygen appears low or unusual, do not diagnose. Mention that the reading may be affected by sensor fit or movement and recommend monitoring trends.
        - If blood pressure or glucose values are present, explain them cautiously and non-diagnostically.
        - If data is incomplete because of a partial sync, timeout, or skipped path, say that the analysis is based only on available synced data.

        BASELINE RULES:
        If 7-day or 30-day baselines are available, compare today against them.
        If baselines are not available, say: "Once more syncs are saved, this analysis will become more personalized because I will be able to compare today against your normal patterns."

        OUTPUT FORMAT:
        Return structured JSON only. Do not wrap it in markdown. Use this exact structure:

        {
          "overall_summary": {
            "score": 0,
            "status": "Excellent | Good | Fair | Needs Attention",
            "summary": "A 2-3 sentence plain-English summary of the user's day, connecting multiple data points.",
            "priority_next_action": "The single most useful action the user should take next."
          },
          "metric_scores": [
            {
              "name": "Sleep Score",
              "score": 0,
              "status": "Excellent | Good | Fair | Needs Attention",
              "reasoning": "1-2 sentences explaining the score using sleep data and sleep-window correlations.",
              "suggested_action": "One practical action."
            },
            {
              "name": "Activity Score",
              "score": 0,
              "status": "Excellent | Good | Fair | Needs Attention",
              "reasoning": "1-2 sentences explaining steps, distance, calories, workouts, and comparison to goals or baseline.",
              "suggested_action": "One practical action."
            },
            {
              "name": "Recovery Score",
              "score": 0,
              "status": "Excellent | Good | Fair | Needs Attention",
              "reasoning": "1-2 sentences connecting sleep, resting heart rate, HRV, activity load, and recovery.",
              "suggested_action": "One practical action."
            },
            {
              "name": "Heart Health Score",
              "score": 0,
              "status": "Excellent | Good | Fair | Needs Attention",
              "reasoning": "1-2 sentences explaining resting heart rate, average heart rate, sleep heart rate, and timestamped spikes.",
              "suggested_action": "One practical action."
            },
            {
              "name": "Stress / Readiness Score",
              "score": 0,
              "status": "Excellent | Good | Fair | Needs Attention",
              "reasoning": "1-2 sentences connecting stress-like patterns, HRV, sleep, heart rate, and activity.",
              "suggested_action": "One practical action."
            }
          ],
          "correlations_found": [
            {
              "title": "Short title of the correlation",
              "data_points": ["Example: sleep duration", "Example: sleep heart rate"],
              "time_window": "The relevant time range, or 'unknown' if not available",
              "explanation": "Explain the relationship clearly and cautiously.",
              "confidence": "High | Medium | Low"
            }
          ],
          "insight_cards": [
            {
              "title": "Short insight title",
              "message": "A useful, personalized insight based on the synced data.",
              "type": "positive | neutral | caution | action"
            }
          ],
          "suggested_actions": [
            {
              "id": "stable-kebab-case-id",
              "title": "Specific action the user can do",
              "category": "hydration | activity | workout | sleep | stress | recovery | general",
              "rationale": "Why this action fits the synced watch data and calendar context.",
              "duration_minutes": 15,
              "intensity": "low | moderate | high",
              "metric_ids": ["activity"],
              "calendar_suitable": true,
              "reminder_suitable": true,
              "notification_cadence": "none | once | every_90_minutes | every_2_hours | daily",
              "alternatives": ["A second option if this action does not fit.", "A lower intensity option."],
              "workout_type": "walk | mobility | stretching | breathing | hiit | none",
              "future_gif_prompt": "If this is a workout, a concise prompt Gemini can later use to make a 15-second exercise demo GIF.",
              "reminder_plan": {
                "cadence": "every_2_hours",
                "start_time": "09:00",
                "end_time": "20:00",
                "max_per_day": 5,
                "message": "Short notification body."
              }
            }
          ],
          "warnings": [
            {
              "title": "Short warning title",
              "message": "Only include if data is unusual, missing, partial, or potentially concerning. Keep it non-diagnostic.",
              "severity": "low | medium | high"
            }
          ],
          "coach_message": "A friendly 2-3 sentence message that sounds like a real coach talking to the user.",
          "source": "ai"
        }

        STYLE RULES:
        - Be clear, friendly, and encouraging.
        - Do not shame the user.
        - Do not sound robotic.
        - Use simple language.
        - Keep each explanation short but meaningful.
        - Focus on what the user can do today.
        - Prefer small realistic suggestions over intense changes.
        - Include 3-5 suggested_actions.
        - Include hydration, light movement, sleep/recovery, breathing/stress, or workout actions only when supported by the data.
        - Make workouts recovery-aware: suggest HIIT only when sleep and recovery look good; otherwise suggest walking, stretching, mobility, or breathing.
        - For calendar timing, use the user's past and future calendar blocks to infer personal routines and protected times. Do not hard-code lunch or any fixed unavailable window.
        - Mention trends, not just single-day values.
        - Do not overreact to one bad day.
        - Do not invent missing data.
        - Do not claim correlations unless timestamps support them.
        - If timestamp overlap is unclear, say the relationship is uncertain.
        - If the sync was partial, mention that the analysis may be limited.

        FINAL IMPORTANT RULE:
        The analysis should feel personalized to this user's actual synced watch data. Do not give generic wellness advice unless it is directly connected to a metric, timestamp, trend, or correlation from the sync.

        Watch data context:
        \(contextJSON)
        """
    }
}
