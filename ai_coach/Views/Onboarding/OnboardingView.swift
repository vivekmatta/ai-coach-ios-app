import SwiftUI

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("AI Wellness Coach")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.appMint)
                    Text("Personalized to you — powered by AI")
                        .font(.system(size: 13))
                        .foregroundColor(.appText.opacity(0.6))
                }
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Chat scroll
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(vm.messages) { msg in
                                OnboardingMessageRow(message: msg)
                                    .id(msg.id)
                            }
                            if vm.isLoading {
                                TypingIndicatorView()
                                    .padding(.leading, 16)
                                    .id("onboard-typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        withAnimation {
                            if let last = vm.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: vm.isLoading) { _ in
                        withAnimation { proxy.scrollTo("onboard-typing", anchor: .bottom) }
                    }
                }

                // Input bar
                HStack(spacing: 10) {
                    TextField("Type your answer...", text: $vm.inputText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.appCard)
                        .foregroundColor(.appText)
                        .cornerRadius(AppRadius.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.input)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                        .disabled(vm.inputDisabled)
                        .onSubmit { vm.sendAnswer() }

                    Button(action: vm.sendAnswer) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(vm.inputDisabled ? .gray : .appAccent)
                    }
                    .disabled(vm.inputDisabled)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .onAppear { vm.start() }
        .onChange(of: vm.isComplete) { complete in
            if complete { onComplete() }
        }
    }
}

struct OnboardingMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "AI Coach")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(message.role == .user ? .appAccent : .appMint)

                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(.appText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.appAccent.opacity(0.15) : Color.appCard)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.appBorder, lineWidth: message.role == .assistant ? 1 : 0)
                    )
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
