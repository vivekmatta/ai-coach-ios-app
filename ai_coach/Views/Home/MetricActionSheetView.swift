import SwiftUI

struct MetricActionSheetView: View {
    let metric: HealthMetric
    var onAskCoach: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.appBorder)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appText)
                    Text(metric.shortInsight)
                        .font(.system(size: 12))
                        .foregroundColor(.appText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(metric.status.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(metric.status.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(metric.status.color.opacity(0.14))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 20)

            // Action rows
            Text("Recommended Actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appText.opacity(0.45))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(metric.actions.enumerated()), id: \.offset) { _, action in
                    ActionRow(action: action, color: metric.color)
                    if action.text != metric.actions.last?.text {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.appCard)
            .cornerRadius(AppRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer()

            // Ask Coach footer button
            Button(action: {
                onAskCoach(metric.coachPrompt)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14))
                    Text("Ask Coach for More →")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(metric.color)
                .cornerRadius(AppRadius.card)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.appBg.ignoresSafeArea())
    }
}

private struct ActionRow: View {
    let action: MetricAction
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: action.icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            Text(action.text)
                .font(.system(size: 14))
                .foregroundColor(.appText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Future action button placeholder (hidden for now)
            // actionButtonPlaceholder(for: action.actionType)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
