import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    var userProfile: UserProfile { PersistenceService.shared.userProfile }

    func loadWelcome() {
        messages = []
        let firstName = userProfile.firstName.isEmpty ? "there" : userProfile.firstName
        messages.append(ChatMessage(
            role: .assistant,
            text: "Hey \(firstName) 👋 I can see today's biometric data. Your recovery score is 44/100 and your body may need some attention today."
        ))
    }

    func sendMessage(_ text: String? = nil) {
        let raw = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isLoading else { return }
        inputText = ""

        messages.append(ChatMessage(role: .user, text: raw))
        isLoading = true

        // Keep rolling window of last 10 messages (excluding typing indicator)
        let historyMessages = Array(messages.dropLast().suffix(10))

        Task {
            let ragContext = await VectorDBService.shared.query(raw)
            let systemPrompt = AppConstants.systemPrompt(for: userProfile, ragContext: ragContext)

            do {
                let response = try await GeminiService.shared.send(
                    systemPrompt: systemPrompt,
                    history: historyMessages,
                    userMessage: raw
                )
                isLoading = false
                messages.append(ChatMessage(role: .assistant, text: response))
            } catch {
                isLoading = false
                messages.append(ChatMessage(role: .assistant, text: "Sorry, I couldn't reach the AI coach right now. Please check your internet connection and API key."))
            }
        }
    }

    func prefill(_ text: String) {
        inputText = text
    }
}
