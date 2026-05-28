import Foundation

struct MetricAIExplanation: Codable, Equatable {
    let metricId: String
    let shortExplanation: String
    let details: String
    let confidence: String
    let dataQuality: String
    let suggestedAction: String?

    static func fallback(metricId: String, value: String, title: String) -> MetricAIExplanation {
        let text: String
        switch metricId {
        case "sleep":
            text = "Sleep reflects recovery time and consistency. Sync after waking so the coach can compare duration, timing, and interruptions."
        case "heartRate":
            text = "Heart rate shows how hard your body is working at the latest reading. Compare it with sleep, activity, and stress context."
        case "oxygen":
            text = "Blood oxygen is a spot check of SpO2 from the watch. Treat single readings as context, not a diagnosis."
        case "hrv":
            text = "HRV is a recovery signal that can move with sleep, stress, hydration, and training load. Trends matter more than one reading."
        case "bloodPressure":
            text = "Blood pressure readings estimate cardiovascular load. Recheck unusual values and use a medical cuff for decisions."
        case "bloodGlucose":
            text = "Glucose readings show stored watch estimates. Food timing, calibration, and device reliability affect the number."
        case "activity":
            text = "Activity combines steps, distance, and calories to show daily movement. Use it with sleep and recovery before pushing harder."
        case "temperature":
            text = "Temperature can reflect body or skin changes depending on the sensor. Watch for trends and confirm anything unusual."
        case "ecg":
            text = "ECG records are offline watch captures. They need careful review and are not a replacement for clinical interpretation."
        case "battery":
            text = "Battery tells you whether the watch can keep collecting data. Low battery can lead to missing health history."
        default:
            text = "\(title) is part of the latest watch sync. More synced history will make this explanation more useful."
        }

        return MetricAIExplanation(
            metricId: metricId,
            shortExplanation: value == "--" ? "No current \(title.lowercased()) value is available yet." : text,
            details: text,
            confidence: value == "--" ? "low" : "medium",
            dataQuality: value == "--" ? "missing" : "available",
            suggestedAction: nil
        )
    }
}

struct VitalReference: Equatable {
    let metricId: String
    let title: String
    let shortRange: String
    let detail: String
    let source: String

    static func reference(for metricId: String) -> VitalReference? {
        references[metricId]
    }

    static let references: [String: VitalReference] = [
        "bloodPressure": VitalReference(
            metricId: "bloodPressure",
            title: "Adult BP reference",
            shortRange: "Normal: <120/<80 mmHg",
            detail: "AHA adult categories: normal is systolic under 120 and diastolic under 80; elevated is 120-129 and under 80; stage 1 is 130-139 or 80-89; stage 2 is 140+ or 90+. Repeated readings matter more than one watch estimate.",
            source: "American Heart Association"
        ),
        "oxygen": VitalReference(
            metricId: "oxygen",
            title: "SpO2 reference",
            shortRange: "Most healthy people: 95-100%",
            detail: "FDA and MedlinePlus describe 95-100% as typical for most healthy people. Values can be lower with altitude or lung/heart conditions; symptoms and repeated readings matter.",
            source: "FDA / MedlinePlus"
        ),
        "heartRate": VitalReference(
            metricId: "heartRate",
            title: "Heart rate reference",
            shortRange: "Ages 12-18 at rest: 60-100 bpm",
            detail: "Cleveland Clinic lists adolescent resting heart rate around 60-100 bpm, similar to the typical adult resting range. Trained athletes can be lower, and context such as activity, stress, illness, caffeine, and sleep matters.",
            source: "Cleveland Clinic / American Heart Association"
        )
    ]
}

struct CoachInsight: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let metricIds: [String]
    let priority: Int
}

struct CoachMetricScore: Codable, Equatable {
    let name: String
    let score: Int
    let status: String
    let reasoning: String
    let suggestedAction: String

    enum CodingKeys: String, CodingKey {
        case name
        case score
        case status
        case reasoning
        case suggestedAction = "suggested_action"
    }
}

struct CoachCorrelation: Codable, Equatable {
    let title: String
    let dataPoints: [String]
    let timeWindow: String
    let explanation: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case title
        case dataPoints = "data_points"
        case timeWindow = "time_window"
        case explanation
        case confidence
    }
}

struct CoachActionReminderPlan: Codable, Equatable {
    let cadence: String
    let startTime: String
    let endTime: String
    let maxPerDay: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case cadence
        case startTime = "start_time"
        case endTime = "end_time"
        case maxPerDay = "max_per_day"
        case message
    }
}

struct CoachSuggestedAction: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let rationale: String
    let durationMinutes: Int
    let intensity: String
    let metricIds: [String]
    let calendarSuitable: Bool
    let reminderSuitable: Bool
    let notificationCadence: String
    let alternatives: [String]
    let workoutType: String?
    let futureGifPrompt: String?
    let reminderPlan: CoachActionReminderPlan?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case rationale
        case durationMinutes = "duration_minutes"
        case intensity
        case metricIds = "metric_ids"
        case calendarSuitable = "calendar_suitable"
        case reminderSuitable = "reminder_suitable"
        case notificationCadence = "notification_cadence"
        case alternatives
        case workoutType = "workout_type"
        case futureGifPrompt = "future_gif_prompt"
        case reminderPlan = "reminder_plan"
    }

    init(
        id: String,
        title: String,
        category: String,
        rationale: String,
        durationMinutes: Int,
        intensity: String,
        metricIds: [String],
        calendarSuitable: Bool,
        reminderSuitable: Bool,
        notificationCadence: String,
        alternatives: [String] = [],
        workoutType: String? = nil,
        futureGifPrompt: String? = nil,
        reminderPlan: CoachActionReminderPlan? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.rationale = rationale
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.metricIds = metricIds
        self.calendarSuitable = calendarSuitable
        self.reminderSuitable = reminderSuitable
        self.notificationCadence = notificationCadence
        self.alternatives = alternatives
        self.workoutType = workoutType
        self.futureGifPrompt = futureGifPrompt
        self.reminderPlan = reminderPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? "Suggested action"
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? Self.stableId(from: decodedTitle)
        self.title = decodedTitle
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "general"
        self.rationale = try container.decodeIfPresent(String.self, forKey: .rationale) ?? ""
        self.durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? Self.durationGuess(from: decodedTitle)
        self.intensity = try container.decodeIfPresent(String.self, forKey: .intensity) ?? "low"
        self.metricIds = try container.decodeIfPresent([String].self, forKey: .metricIds) ?? []
        self.calendarSuitable = try container.decodeIfPresent(Bool.self, forKey: .calendarSuitable) ?? true
        self.reminderSuitable = try container.decodeIfPresent(Bool.self, forKey: .reminderSuitable) ?? false
        self.notificationCadence = try container.decodeIfPresent(String.self, forKey: .notificationCadence) ?? "none"
        self.alternatives = try container.decodeIfPresent([String].self, forKey: .alternatives) ?? []
        self.workoutType = try container.decodeIfPresent(String.self, forKey: .workoutType)
        self.futureGifPrompt = try container.decodeIfPresent(String.self, forKey: .futureGifPrompt)
        self.reminderPlan = try container.decodeIfPresent(CoachActionReminderPlan.self, forKey: .reminderPlan)
    }

    static func legacy(_ title: String, metricId: String? = nil, rationale: String = "") -> CoachSuggestedAction {
        let normalized = title.lowercased()
        let category: String
        if normalized.contains("water") || normalized.contains("hydrat") {
            category = "hydration"
        } else if normalized.contains("walk") || normalized.contains("step") || normalized.contains("hiit") || normalized.contains("workout") {
            category = "activity"
        } else if normalized.contains("sleep") || normalized.contains("bed") {
            category = "sleep"
        } else if normalized.contains("breath") || normalized.contains("stress") {
            category = "stress"
        } else {
            category = "general"
        }

        return CoachSuggestedAction(
            id: stableId(from: title),
            title: title,
            category: category,
            rationale: rationale,
            durationMinutes: durationGuess(from: title),
            intensity: normalized.contains("hiit") ? "high" : "low",
            metricIds: metricId.map { [$0] } ?? [],
            calendarSuitable: true,
            reminderSuitable: category == "hydration" || category == "activity" || category == "sleep",
            notificationCadence: category == "hydration" ? "every_2_hours" : "once",
            alternatives: []
        )
    }

    private static func durationGuess(from text: String) -> Int {
        let lower = text.lowercased()
        if lower.contains("hiit") { return 15 }
        if lower.contains("walk") { return 15 }
        if lower.contains("breath") { return 5 }
        if lower.contains("stretch") || lower.contains("mobility") { return 10 }
        return 15
    }

    private static func stableId(from title: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = title.lowercased().unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(scalars).split(separator: "-").joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString : slug
    }
}

struct AICoachAnalysis: Codable, Equatable {
    let syncId: String
    let generatedAt: String
    let overallSummary: String
    let priority: String
    let metricExplanations: [String: MetricAIExplanation]
    let insightCards: [CoachInsight]
    let warnings: [String]
    let source: String
    let overallScore: Int?
    let overallStatus: String?
    let metricScores: [CoachMetricScore]
    let correlationsFound: [CoachCorrelation]
    let coachMessage: String
    let suggestedActions: [CoachSuggestedAction]

    var isAIBacked: Bool {
        source == "ai" || source == "firebase_ai_logic" || source == "ai_cached"
    }

    init(
        syncId: String,
        generatedAt: String,
        overallSummary: String,
        priority: String,
        metricExplanations: [String: MetricAIExplanation],
        insightCards: [CoachInsight],
        warnings: [String],
        source: String,
        overallScore: Int? = nil,
        overallStatus: String? = nil,
        metricScores: [CoachMetricScore] = [],
        correlationsFound: [CoachCorrelation] = [],
        coachMessage: String = "",
        suggestedActions: [CoachSuggestedAction] = []
    ) {
        self.syncId = syncId
        self.generatedAt = generatedAt
        self.overallSummary = overallSummary
        self.priority = priority
        self.metricExplanations = metricExplanations
        self.insightCards = insightCards
        self.warnings = warnings
        self.source = source
        self.overallScore = overallScore
        self.overallStatus = overallStatus
        self.metricScores = metricScores
        self.correlationsFound = correlationsFound
        self.coachMessage = coachMessage
        self.suggestedActions = suggestedActions
    }

    enum LegacyCodingKeys: String, CodingKey {
        case syncId
        case generatedAt
        case overallSummary
        case priority
        case metricExplanations
        case insightCards
        case warnings
        case source
        case overallScore
        case overallStatus
        case metricScores
        case correlationsFound
        case coachMessage
        case suggestedActions
    }

    enum StructuredCodingKeys: String, CodingKey {
        case overallSummary = "overall_summary"
        case metricScores = "metric_scores"
        case correlationsFound = "correlations_found"
        case insightCards = "insight_cards"
        case warnings
        case coachMessage = "coach_message"
        case suggestedActions = "suggested_actions"
        case source
    }

    private struct StructuredOverallSummary: Codable {
        let score: Int
        let status: String
        let summary: String
        let priorityNextAction: String

        enum CodingKeys: String, CodingKey {
            case score
            case status
            case summary
            case priorityNextAction = "priority_next_action"
        }
    }

    private struct StructuredInsightCard: Codable {
        let title: String
        let message: String
        let type: String
    }

    private struct StructuredWarning: Codable {
        let title: String
        let message: String
        let severity: String
    }

    init(from decoder: Decoder) throws {
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if legacy.contains(.overallSummary) {
            self.syncId = try legacy.decodeIfPresent(String.self, forKey: .syncId) ?? ""
            self.generatedAt = try legacy.decodeIfPresent(String.self, forKey: .generatedAt) ?? Self.nowString()
            self.overallSummary = try legacy.decode(String.self, forKey: .overallSummary)
            self.priority = try legacy.decode(String.self, forKey: .priority)
            self.metricExplanations = try legacy.decodeIfPresent([String: MetricAIExplanation].self, forKey: .metricExplanations) ?? [:]
            self.insightCards = try legacy.decodeIfPresent([CoachInsight].self, forKey: .insightCards) ?? []
            self.warnings = try legacy.decodeIfPresent([String].self, forKey: .warnings) ?? []
            self.source = try legacy.decodeIfPresent(String.self, forKey: .source) ?? "ai"
            self.overallScore = try legacy.decodeIfPresent(Int.self, forKey: .overallScore)
            self.overallStatus = try legacy.decodeIfPresent(String.self, forKey: .overallStatus)
            let legacyScores = try legacy.decodeIfPresent([CoachMetricScore].self, forKey: .metricScores) ?? []
            self.metricScores = legacyScores
            self.correlationsFound = try legacy.decodeIfPresent([CoachCorrelation].self, forKey: .correlationsFound) ?? []
            self.coachMessage = try legacy.decodeIfPresent(String.self, forKey: .coachMessage) ?? ""
            self.suggestedActions = try legacy.decodeIfPresent([CoachSuggestedAction].self, forKey: .suggestedActions) ?? Self.actions(from: legacyScores, priority: self.priority)
            return
        }

        let structured = try decoder.container(keyedBy: StructuredCodingKeys.self)
        let summary = try structured.decode(StructuredOverallSummary.self, forKey: .overallSummary)
        let scores = try structured.decodeIfPresent([CoachMetricScore].self, forKey: .metricScores) ?? []
        let rawInsights = try structured.decodeIfPresent([StructuredInsightCard].self, forKey: .insightCards) ?? []
        let rawWarnings = try structured.decodeIfPresent([StructuredWarning].self, forKey: .warnings) ?? []

        self.syncId = ""
        self.generatedAt = Self.nowString()
        self.overallSummary = summary.summary
        self.priority = summary.priorityNextAction
        self.metricExplanations = Self.metricExplanations(from: scores)
        self.insightCards = rawInsights.enumerated().map { index, card in
            CoachInsight(
                id: "\(Self.stableId(from: card.title))-\(index + 1)",
                title: card.title,
                body: card.message,
                metricIds: [],
                priority: index + 1
            )
        }
        self.warnings = rawWarnings.map { "\($0.title): \($0.message)" }
        self.source = try structured.decodeIfPresent(String.self, forKey: .source) ?? "ai"
        self.overallScore = summary.score
        self.overallStatus = summary.status
        self.metricScores = scores
        self.correlationsFound = try structured.decodeIfPresent([CoachCorrelation].self, forKey: .correlationsFound) ?? []
        self.coachMessage = try structured.decodeIfPresent(String.self, forKey: .coachMessage) ?? ""
        self.suggestedActions = try structured.decodeIfPresent([CoachSuggestedAction].self, forKey: .suggestedActions) ?? Self.actions(from: scores, priority: summary.priorityNextAction)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LegacyCodingKeys.self)
        try container.encode(syncId, forKey: .syncId)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(overallSummary, forKey: .overallSummary)
        try container.encode(priority, forKey: .priority)
        try container.encode(metricExplanations, forKey: .metricExplanations)
        try container.encode(insightCards, forKey: .insightCards)
        try container.encode(warnings, forKey: .warnings)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(overallScore, forKey: .overallScore)
        try container.encodeIfPresent(overallStatus, forKey: .overallStatus)
        try container.encode(metricScores, forKey: .metricScores)
        try container.encode(correlationsFound, forKey: .correlationsFound)
        try container.encode(coachMessage, forKey: .coachMessage)
        try container.encode(suggestedActions, forKey: .suggestedActions)
    }

    static let empty = AICoachAnalysis(
        syncId: "",
        generatedAt: "",
        overallSummary: "Sync your watch to generate a coach summary.",
        priority: "Open the app near your watch and run a sync.",
        metricExplanations: [:],
        insightCards: [],
            warnings: [],
            source: "empty",
            suggestedActions: []
        )

    static func localFallback(syncId: String, generatedAt: String, metrics: [HealthMetricSummary]) -> AICoachAnalysis {
        let explanations = Dictionary(uniqueKeysWithValues: metrics.map {
            ($0.metricId, MetricAIExplanation.fallback(metricId: $0.metricId, value: $0.value, title: $0.title))
        })

        let available = metrics.filter { $0.value != "--" }
        let summary: String
        if available.isEmpty {
            summary = "No fresh watch measurements are available yet. Sync the watch so the coach can compare sleep, recovery, and activity."
        } else {
            let names = available.prefix(4).map(\.title).joined(separator: ", ")
            summary = "The latest sync has usable data for \(names). Use the detailed cards to check recovery, activity, and data quality before acting on one number."
        }

        return AICoachAnalysis(
            syncId: syncId,
            generatedAt: generatedAt,
            overallSummary: summary,
            priority: available.isEmpty ? "Run a fresh watch sync." : "Review sleep and recovery first, then compare activity against how rested you look.",
            metricExplanations: explanations,
            insightCards: [
                CoachInsight(
                    id: "data-quality",
                    title: "Data quality",
                    body: "More consecutive daily syncs will make the coach output more useful than isolated readings.",
                    metricIds: available.map(\.metricId),
                    priority: 1
                )
            ],
            warnings: ["This coaching is informational and is not a diagnosis."],
            source: "local_fallback",
            suggestedActions: available.isEmpty ? [
                CoachSuggestedAction.legacy("Run a fresh watch sync.", metricId: nil)
            ] : [
                CoachSuggestedAction.legacy("Take a 15-minute easy walk when your calendar has a natural opening.", metricId: "activity"),
                CoachSuggestedAction.legacy("Drink water steadily through your next free stretch.", metricId: "hrv"),
                CoachSuggestedAction.legacy("Review sleep and recovery before choosing a hard workout.", metricId: "sleep")
            ]
        )
    }

    func reusedForSync(syncId: String, generatedAt: String) -> AICoachAnalysis {
        AICoachAnalysis(
            syncId: syncId,
            generatedAt: generatedAt,
            overallSummary: overallSummary,
            priority: priority,
            metricExplanations: metricExplanations,
            insightCards: insightCards,
            warnings: warnings,
            source: "ai_cached",
            overallScore: overallScore,
            overallStatus: overallStatus,
            metricScores: metricScores,
            correlationsFound: correlationsFound,
            coachMessage: coachMessage,
            suggestedActions: suggestedActions
        )
    }

    private static func actions(from scores: [CoachMetricScore], priority: String) -> [CoachSuggestedAction] {
        var actions = scores.compactMap { score -> CoachSuggestedAction? in
            let action = score.suggestedAction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !action.isEmpty else { return nil }
            return CoachSuggestedAction.legacy(action, metricId: metricId(for: score.name), rationale: score.reasoning)
        }
        if actions.isEmpty, !priority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.append(CoachSuggestedAction.legacy(priority))
        }
        return actions
    }

    private static func metricExplanations(from scores: [CoachMetricScore]) -> [String: MetricAIExplanation] {
        var explanations: [String: MetricAIExplanation] = [:]
        for score in scores {
            guard let metricId = metricId(for: score.name) else { continue }
            if let existing = explanations[metricId] {
                explanations[metricId] = MetricAIExplanation(
                    metricId: metricId,
                    shortExplanation: existing.shortExplanation,
                    details: "\(existing.details)\n\(score.name): \(score.reasoning)",
                    confidence: existing.confidence,
                    dataQuality: existing.dataQuality,
                    suggestedAction: [existing.suggestedAction, score.suggestedAction]
                        .compactMap { $0 }
                        .joined(separator: "\n")
                )
            } else {
                explanations[metricId] =
                MetricAIExplanation(
                    metricId: metricId,
                    shortExplanation: "\(score.status): \(score.reasoning)",
                    details: "Score: \(score.score)/100. \(score.reasoning)",
                    confidence: "medium",
                    dataQuality: "available",
                    suggestedAction: score.suggestedAction
                )
            }
        }
        return explanations
    }

    private static func metricId(for scoreName: String) -> String? {
        let normalized = scoreName.lowercased()
        if normalized.contains("sleep") { return "sleep" }
        if normalized.contains("activity") { return "activity" }
        if normalized.contains("heart") { return "heartRate" }
        if normalized.contains("stress") || normalized.contains("readiness") { return "hrv" }
        if normalized.contains("recovery") { return "hrv" }
        return nil
    }

    private static func stableId(from title: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = title.lowercased().unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(scalars).split(separator: "-").joined(separator: "-")
    }

    private static func nowString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

struct HealthMetricSummary: Codable, Equatable {
    let metricId: String
    let title: String
    let value: String
    let unit: String
    let date: String
    let detail: String
}
