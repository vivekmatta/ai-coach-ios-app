import Foundation

struct MetricAIExplanation: Codable, Equatable {
    let metricId: String
    let shortExplanation: String
    let details: String
    let confidence: String
    let dataQuality: String

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
            dataQuality: value == "--" ? "missing" : "available"
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
            title: "Resting HR reference",
            shortRange: "Adults at rest: 60-100 bpm",
            detail: "AHA describes 60-100 bpm as the normal average resting adult range. Trained athletes can be lower, and context such as activity, stress, illness, caffeine, and sleep matters.",
            source: "American Heart Association"
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

struct AICoachAnalysis: Codable, Equatable {
    let syncId: String
    let generatedAt: String
    let overallSummary: String
    let priority: String
    let metricExplanations: [String: MetricAIExplanation]
    let insightCards: [CoachInsight]
    let warnings: [String]
    let source: String

    static let empty = AICoachAnalysis(
        syncId: "",
        generatedAt: "",
        overallSummary: "Sync your watch to generate a coach summary.",
        priority: "Open the app near your watch and run a sync.",
        metricExplanations: [:],
        insightCards: [],
        warnings: [],
        source: "empty"
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
            source: "local_fallback"
        )
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
