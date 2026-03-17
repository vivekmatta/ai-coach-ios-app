import SwiftUI

struct MetricCardView: View {
    let metric: HealthMetric
    var onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(metric.color)
                    .frame(width: 3)
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 9) {

                    // Top row: name + status badge
                    HStack(alignment: .center, spacing: 6) {
                        Text(metric.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.appText.opacity(0.55))
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

                    // Short insight text (replaces the numeric value)
                    Text(metric.shortInsight)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.appText.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Sparkline
                    SparklineView(data: metric.trend, color: metric.color)

                    // Bottom row: baseline + tap hint
                    HStack {
                        Text(metric.baseline)
                            .font(.system(size: 10))
                            .foregroundColor(.appText.opacity(0.35))
                            .lineLimit(1)
                        Spacer()
                        Text("Details →")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(metric.color.opacity(0.7))
                    }
                }
                .padding(.leading, 11)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .background(Color.appCard)
            .cornerRadius(AppRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
