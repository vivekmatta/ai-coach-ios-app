import Foundation

struct WellnessBreakdownItem: Identifiable {
    let id = UUID()
    let name: String
    let score: Double   // 0.0 – 1.0
    let weight: Double  // 0.0 – 1.0
}

let wellnessBreakdownItems: [WellnessBreakdownItem] = [
    WellnessBreakdownItem(name: "HRV",        score: 0.73, weight: 0.25),
    WellnessBreakdownItem(name: "Sleep",      score: 0.61, weight: 0.25),
    WellnessBreakdownItem(name: "Recovery",   score: 0.44, weight: 0.25),
    WellnessBreakdownItem(name: "Resting HR", score: 0.90, weight: 0.15),
    WellnessBreakdownItem(name: "Steps",      score: 0.32, weight: 0.05),
    WellnessBreakdownItem(name: "Stress",     score: 0.25, weight: 0.05),
]

let wellnessScore: Int = 62
