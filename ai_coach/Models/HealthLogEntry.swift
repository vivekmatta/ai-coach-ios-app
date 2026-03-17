import Foundation

struct HealthLogEntry: Identifiable {
    let id = UUID()
    let date: String
    let hrv: String
    let sleep: String
    let recovery: String
    let rhr: String
    let steps: String
    let stress: String
    let notes: String
}
