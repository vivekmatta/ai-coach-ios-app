import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Coach Chat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.appBorder)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Quick prompt buttons on welcome
                        if vm.messages.count == 1, vm.messages.first?.role == .assistant {
                            quickPrompts
                        }

                        ForEach(vm.messages) { msg in
                            ChatMessageRow(message: msg)
                                .id(msg.id)
                        }

                        if vm.isLoading {
                            HStack {
                                TypingIndicatorView()
                                Spacer()
                            }
                            .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) { _ in
                    withAnimation { proxy.scrollTo(vm.messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: vm.isLoading) { loading in
                    if loading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }

            Divider().background(Color.appBorder)

            // Input bar
            HStack(spacing: 10) {
                TextField("Ask your coach anything...", text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appBgSecondary)
                    .foregroundColor(.appText)
                    .cornerRadius(AppRadius.input)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.input)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .onSubmit { vm.sendMessage() }

                Button(action: { vm.sendMessage() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(vm.isLoading ? .gray : .appAccent)
                }
                .disabled(vm.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appBg)
        .onAppear { vm.loadWelcome() }
    }

    private var quickPrompts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking me:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appText.opacity(0.6))

            ForEach([
                ("📋", "Give me a plan for today based on my current biometrics and goals"),
                ("📉", "Why is my HRV low and what can I do about it?"),
                ("😴", "How is my sleep affecting my energy and performance?")
            ], id: \.0) { emoji, prompt in
                Button(action: { vm.sendMessage(prompt) }) {
                    HStack(spacing: 8) {
                        Text(emoji)
                        Text(prompt)
                            .font(.system(size: 13))
                            .foregroundColor(.appText)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}
