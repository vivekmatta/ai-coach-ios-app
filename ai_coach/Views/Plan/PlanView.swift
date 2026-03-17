import SwiftUI

struct PlanView: View {
    @StateObject private var vm = PlanViewModel()
    var onRefineInChat: (String) -> Void

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personalized Wellness Plan")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appText)
                        Text("Your plan is generated from your goals, physiological signals, and sleep & stress trends.")
                            .font(.system(size: 13))
                            .foregroundColor(.appText.opacity(0.6))
                    }

                    // How it works card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How it works")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText)

                        HStack(spacing: 8) {
                            ForEach([
                                ("1", "Goals + biometrics analyzed"),
                                ("2", "Weekly plan generated"),
                                ("3", "Results reviewed"),
                                ("4", "Plan adjusted")
                            ], id: \.0) { num, label in
                                VStack(spacing: 4) {
                                    Text(num)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.appBg)
                                        .frame(width: 22, height: 22)
                                        .background(Color.appAccent)
                                        .clipShape(Circle())
                                    Text(label)
                                        .font(.system(size: 10))
                                        .foregroundColor(.appText.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.appCard)
                    .cornerRadius(AppRadius.card)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))

                    // Chips
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(zip(AppConstants.planChipLabels, AppConstants.planChips)), id: \.0) { label, prompt in
                            Button(action: { vm.setPlanInput(prompt) }) {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.appAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.appAccent.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appAccent.opacity(0.3), lineWidth: 1))
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Input
                    VStack(spacing: 10) {
                        ZStack(alignment: .topLeading) {
                            if vm.planInput.isEmpty {
                                Text("e.g. 'I want to run a half marathon in 6 weeks — make me a full plan' or 'help me improve my sleep'...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.appText.opacity(0.35))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                            }
                            TextEditor(text: $vm.planInput)
                                .frame(minHeight: 80)
                                .font(.system(size: 13))
                                .foregroundColor(.appText)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .background(Color.appCard)
                        .cornerRadius(AppRadius.input)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.input).stroke(Color.appBorder, lineWidth: 1))

                        Button(action: vm.generatePlan) {
                            HStack {
                                if vm.isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Generating...")
                                } else {
                                    Text("Generate Plan")
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.isGenerating ? Color.appAccent.opacity(0.5) : Color.appAccent)
                            .cornerRadius(AppRadius.card)
                        }
                        .disabled(vm.isGenerating || vm.planInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }

                    // Plan output
                    if !vm.generatedPlan.isEmpty {
                        PlanOutputView(plan: vm.generatedPlan) {
                            vm.regenerate()
                        } onRefine: {
                            let refineText = vm.refineInChat()
                            onRefineInChat(refineText)
                        }
                    }

                    // Coming soon placeholder
                    VStack(spacing: 8) {
                        Text("🎬").font(.system(size: 32))
                        Text("AI Workout Demonstrations")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText)
                        Text("Coming soon — personalized exercise videos with voice guidance")
                            .font(.system(size: 12))
                            .foregroundColor(.appText.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.appCard)
                    .cornerRadius(AppRadius.card)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

struct PlanOutputView: View {
    let plan: String
    var onRegenerate: () -> Void
    var onRefine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Personalized Plan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appText)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onRegenerate) {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)

                    Button(action: onRefine) {
                        Label("Refine", systemImage: "bubble.left.and.bubble.right")
                            .font(.system(size: 12))
                            .foregroundColor(.appMint)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().background(Color.appBorder)

            MarkdownText(text: plan)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(AppRadius.card)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))
    }
}
