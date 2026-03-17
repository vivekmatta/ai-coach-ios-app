import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var metrics: [HealthMetric] = AppConstants.metrics
    @Published var selectedMetric: HealthMetric? = nil
    @Published var showBreakdownSheet: Bool = false
    @Published var gaugeAnimated: Bool = false

    var score: Int { wellnessScore }

    func onAppear() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeInOut(duration: 1.2)) {
                gaugeAnimated = true
            }
        }
    }

    func selectMetric(_ metric: HealthMetric) {
        selectedMetric = metric
    }

    func dismissDetail() {
        selectedMetric = nil
    }
}
