import SwiftUI

/// A LabelStyle that shows a bullet dot instead of the SF symbol
struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundColor(.appAccent).font(.system(size: 14))
            configuration.title
        }
    }
}

struct MetricDetailSheetView: View {
    let metric: HealthMetric
    var onAskCoach: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Score reveal header
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text(metric.value)
                                    .font(.system(size: 52, weight: .bold))
                                    .foregroundColor(.appText)
                                if !metric.unit.isEmpty {
                                    Text(metric.unit)
                                        .font(.system(size: 22))
                                        .foregroundColor(.appText.opacity(0.45))
                                }
                                Spacer()
                                Text(metric.status.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(metric.status.color)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(metric.status.color.opacity(0.15))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(metric.status.color.opacity(0.3), lineWidth: 1))
                            }

                            // Accent divider line
                            Rectangle()
                                .fill(metric.color.opacity(0.5))
                                .frame(height: 2)
                                .cornerRadius(1)

                            Text(metric.baseline)
                                .font(.system(size: 12))
                                .foregroundColor(.appText.opacity(0.5))
                        }

                        // Trend chart
                        TrendChartView(data: metric.trend, color: metric.color)
                            .padding(.top, -4)

                        // What This Means
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What This Means")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appText)
                            Text(metric.description)
                                .font(.system(size: 13))
                                .foregroundColor(.appText.opacity(0.75))
                        }
                        .padding(14)
                        .background(Color.appCard)
                        .cornerRadius(AppRadius.card)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))

                        // Metric-specific sub-view
                        detailSubView
                            .padding(14)
                            .background(Color.appCard)
                            .cornerRadius(AppRadius.card)
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))

                        // Ask Coach
                        Button(action: {
                            dismiss()
                            onAskCoach(metric.coachPrompt)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text("Ask Coach About This")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.appBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.appAccent)
                            .cornerRadius(AppRadius.card)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var detailSubView: some View {
        switch metric.id {
        case .hrv:      HRVDetailView()
        case .sleep:    SleepDetailView()
        case .recovery: RecoveryDetailView()
        case .rhr:      RHRDetailView()
        case .steps:    StepsDetailView()
        case .stress:   StressDetailView()
        case .temp:     TempDetailView()
        }
    }
}
