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
    var fullWidth: Bool = false
}
