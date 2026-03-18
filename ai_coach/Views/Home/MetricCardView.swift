import SwiftUI

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct MetricCardView: View {
    let metric: HealthMetric
    var onTap: () -> Void
    var onAction: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(metric.color)
                    .frame(width: 3)
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 12) {

                    // Top row: name + status badge
                    HStack(alignment: .center, spacing: 6) {
                        Text(metric.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appText.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text(metric.status.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(metric.status.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(metric.status.color.opacity(0.14))
                            .cornerRadius(6)
                    }

                    // Short insight text — full text, no line limit
                    Text(metric.shortInsight)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.appText.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)

                    // Sparkline
                    SparklineView(data: metric.trend, color: metric.color)

                    // Bottom row: baseline + action button
                    HStack {
                        Text(metric.baseline)
                            .font(.system(size: 10))
                            .foregroundColor(.appText.opacity(0.35))
                            .lineLimit(1)
                        Spacer()
                        Button(action: onAction) {
                            Text("Actions →")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(metric.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(metric.color.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 11)
                .padding(.trailing, 14)
                .padding(.vertical, 18)
            }
            .background(Color.appCard)
            .cornerRadius(AppRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
        .buttonStyle(CardPressStyle())
    }
}
