import SwiftUI

enum MetricKey: String, CaseIterable, Identifiable {
    case hrv, sleep, recovery, rhr, steps, stress, temp
    var id: String { rawValue }
}

enum MetricStatus: String {
    case good       = "Good"
    case normal     = "Normal"
    case low        = "Low"
    case elevated   = "Elevated"
    case belowAvg   = "Below Average"
    case needsRest  = "Needs Rest"
    case high       = "High"

    var color: Color {
        switch self {
        case .good, .normal:    return .appMint
        case .low, .belowAvg:  return .appAccent
        case .elevated, .high, .needsRest: return .appCoral
        }
    }
}

enum MetricActionType {
    case info       // just a recommendation, no button
    case calendar   // future: "Add to Calendar"
    case shortcut   // future: "Open App / Shortcut"
    case chat       // opens pre-filled coach chat
}

struct MetricAction {
    let icon: String           // SF Symbol name
    let text: String           // action description
    let actionType: MetricActionType
}

struct HealthMetric: Identifiable {
    let id: MetricKey
    let name: String
    let value: String
    let unit: String
    let baseline: String
    let status: MetricStatus
    let trend: [Double]
    let color: Color
    let shortInsight: String
    let description: String
    let coachPrompt: String
    var actions: [MetricAction] = []
    var fullWidth: Bool = false
}
