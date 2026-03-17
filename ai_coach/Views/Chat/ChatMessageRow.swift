import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 50) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "AI Coach")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(message.role == .user ? .appAccent : .appMint)

                if message.role == .assistant {
                    MarkdownText(text: message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.appCard)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                } else {
                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundColor(.appText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.appAccent.opacity(0.2))
                        .cornerRadius(14)
                }
            }

            if message.role == .assistant { Spacer(minLength: 50) }
        }
    }
}
