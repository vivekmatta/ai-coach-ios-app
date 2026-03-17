import SwiftUI

enum WorkoutType: String, CaseIterable, Codable {
    case run   = "run"
    case swim  = "swim"
    case brick = "brick"
    case yoga  = "yoga"
    case rest  = "rest"

    var label: String {
        switch self {
        case .run:   return "Run"
        case .swim:  return "Swim"
        case .brick: return "Brick"
        case .yoga:  return "Yoga"
        case .rest:  return "Rest"
        }
    }

    var color: Color {
        switch self {
        case .run:   return .appAccent
        case .swim:  return Color(hex: "#2cb7b0")
        case .brick: return Color(hex: "#f5a623")
        case .yoga:  return Color(hex: "#6bbd6e")
        case .rest:  return Color(hex: "#555555")
        }
    }
}

struct WorkoutEntry: Identifiable, Equatable {
    var id: Int
    var date: String
    var type: WorkoutType
    var typeLabel: String
    var duration: String
    var distance: String
    var avgHR: String
    var effort: String
    var notes: String
}
