import Foundation

enum MessageRole: String {
    case user      = "user"
    case assistant = "model"
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var isTyping: Bool = false
}
