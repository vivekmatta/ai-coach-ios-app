import Foundation
import Combine
import SwiftUI

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var planInput: String = ""
    @Published var generatedPlan: String = ""
    @Published var isGenerating: Bool = false
    @Published var switchToHomeWithChat: String? = nil

    var userProfile: UserProfile { PersistenceService.shared.userProfile }

    func setPlanInput(_ text: String) {
        planInput = text
    }

    func generatePlan() {
        let raw = planInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isGenerating else { return }
        isGenerating = true

        let profile = userProfile
        let prompt = buildPrompt(raw, profile: profile)

        Task {
            let ragContext = await VectorDBService.shared.query(raw)
            let systemPrompt = AppConstants.systemPrompt(for: profile, ragContext: ragContext)
            do {
                let response = try await GeminiService.shared.send(
                    systemPrompt: systemPrompt,
                    history: [],
                    userMessage: prompt
                )
                isGenerating = false
                generatedPlan = response
            } catch {
                isGenerating = false
                generatedPlan = "Could not generate plan. Please check your internet connection and API key."
            }
        }
    }

    func regenerate() {
        generatePlan()
    }

    func refineInChat() -> String {
        let preview = String(generatedPlan.prefix(300))
        return "I have this plan: \(preview)... please help me refine it"
    }

    private func buildPrompt(_ request: String, profile: UserProfile) -> String {
        """
        User request: \(request)

        User profile:
        - Name: \(profile.name.isEmpty ? "Alex" : profile.name)
        - Goals: \(profile.goals.isEmpty ? "Improve wellness" : profile.goals)
        - Exercise days/week: \(profile.exerciseDays)
        - Exercise type: \(profile.exerciseType)
        - Sleep time: \(profile.sleepTime)
        - Caffeine use: \(profile.caffeine)
        - Work stress: \(profile.workStress)

        Today's biometrics: HRV 38ms (baseline 52ms, Low), Sleep 61/100 (Below Average), Recovery 44/100 (Needs Rest), RHR 58 bpm (Elevated), Steps 3,200 (Low), Stress High.

        Generate a detailed, personalized wellness plan based on this request and the user's current health data. Format with clear sections, bullet points, and specific actionable recommendations.
        """
    }
}
