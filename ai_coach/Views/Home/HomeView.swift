import SwiftUI

struct HomeView: View {
    @StateObject private var homeVM = HomeViewModel()
    @ObservedObject var chatVM: ChatViewModel
    @State private var showBreakdown = false
    private let columns = [GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Banner
                    stressBanner

                    // ── Wellness Gauge
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            WellnessGaugeView(
                                score: wellnessScore,
                                animated: homeVM.gaugeAnimated,
                                onTap: { showBreakdown = true }
                            )
                            Text("Tap for breakdown")
                                .font(.system(size: 11))
                                .foregroundColor(.appText.opacity(0.4))
                        }
                        Spacer()
                    }

                    // ── Metric Cards (2-column grid, temp spans full width)
                    let regular = homeVM.metrics.filter { !$0.fullWidth }
                    let wide    = homeVM.metrics.filter { $0.fullWidth }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(regular) { metric in
                            MetricCardView(metric: metric) {
                                homeVM.selectMetric(metric)
                            }
                        }
                    }

                    ForEach(wide) { metric in
                        MetricCardView(metric: metric) {
                            homeVM.selectMetric(metric)
                        }
                    }

                    // ── Glucose Insight
                    GlucoseInsightView { prompt in
                        chatVM.prefill(prompt)
                    }

                    // ── Chat section
                    ChatView(vm: chatVM)
                        .background(Color.appCard)
                        .cornerRadius(AppRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.card)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                        .frame(minHeight: 420)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .onAppear { homeVM.onAppear() }
        .sheet(isPresented: $showBreakdown) {
            WellnessBreakdownSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $homeVM.selectedMetric) { metric in
            MetricDetailSheetView(metric: metric) { prompt in
                chatVM.prefill(prompt)
            }
            .presentationDetents([.large])
        }
    }

    private var stressBanner: some View {
        HStack(spacing: 12) {
            Text("⚡")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("High stress detected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appCoral)
                Text("Early wake-up + HRV below baseline. Rest day recommended.")
                    .font(.system(size: 12))
                    .foregroundColor(.appText.opacity(0.65))
            }
            Spacer()
            Button(action: {
                chatVM.prefill("I'm feeling stressed because...")
            }) {
                Text("Tell coach")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appMint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appMint.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appMint.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.appCoral.opacity(0.08))
        .cornerRadius(AppRadius.card)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appCoral.opacity(0.2), lineWidth: 1))
    }
}
