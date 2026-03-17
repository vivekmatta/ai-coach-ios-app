import Foundation
import Combine
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isComplete: Bool = false
    @Published var isLoading: Bool = false
    @Published var inputDisabled: Bool = false

    private var answers: [String] = []
    private var step: Int = 0
    private let questions = AppConstants.onboardingQuestions

    func start() {
        // Kick off background vector DB build
        Task.detached(priority: .background) {
            await VectorDBService.shared.buildIfNeeded()
        }
        // Show first question after short delay
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            appendMessage(role: .assistant, text: questions[0])
        }
    }

    func sendAnswer() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !inputDisabled else { return }
        inputText = ""
        appendMessage(role: .user, text: text)
        answers.append(text)
        step += 1

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if step < questions.count {
                appendMessage(role: .assistant, text: questions[step])
            } else {
                await completeOnboarding()
            }
        }
    }

    private func completeOnboarding() async {
        inputDisabled = true
        appendMessage(role: .assistant, text: "Perfect! I've got everything I need. Let me set up your dashboard...")

        let profile = UserProfile(
            name:         answers.indices.contains(0) ? answers[0] : "Alex",
            goals:        answers.indices.contains(1) ? answers[1] : "Improve wellness",
            exerciseDays: answers.indices.contains(2) ? answers[2] : "",
            exerciseType: answers.indices.contains(3) ? answers[3] : "",
            sleepTime:    answers.indices.contains(4) ? answers[4] : "",
            caffeine:     answers.indices.contains(5) ? answers[5] : "",
            workStress:   answers.indices.contains(6) ? answers[6] : ""
        )

        PersistenceService.shared.userProfile = profile
        PersistenceService.shared.onboardingComplete = true

        // Generate personalized welcome via Gemini
        isLoading = true
        do {
            let summaryPrompt = """
The user just completed onboarding. Their profile: Name: \(profile.name), Wellness Goals: \(profile.goals), Exercise Days/Week: \(profile.exerciseDays), Exercise Type: \(profile.exerciseType), Sleep Time: \(profile.sleepTime), Caffeine: \(profile.caffeine), Work Stress: \(profile.workStress). Write a warm, encouraging 2-3 sentence welcome message addressing them by first name, acknowledging their wellness goals, and noting you're ready to help them feel their best. Keep it brief and friendly.
"""
            let response = try await GeminiService.shared.send(
                systemPrompt: AppConstants.systemPrompt(for: profile),
                history: [],
                userMessage: summaryPrompt
            )
            isLoading = false
            appendMessage(role: .assistant, text: response)
        } catch {
            isLoading = false
            appendMessage(role: .assistant, text: "Welcome, \(profile.firstName)! I'm excited to help you reach your goals. Your dashboard is ready — let's get started!")
        }

        try? await Task.sleep(for: .seconds(2))
        withAnimation(.easeInOut(duration: 0.5)) {
            isComplete = true
        }
    }

    private func appendMessage(role: MessageRole, text: String) {
        messages.append(ChatMessage(role: role, text: text))
    }
}
