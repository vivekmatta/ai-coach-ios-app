import SwiftUI

struct WellnessGaugeView: View {
    let score: Int
    let animated: Bool
    var onTap: () -> Void

    private var gaugeColor: Color {
        score > 75 ? .appMint : score >= 50 ? .appAccent : .appCoral
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.appBorder, lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Animated arc
                Circle()
                    .trim(from: 0, to: animated ? CGFloat(score) / 100 : 0)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.easeInOut(duration: 1.2), value: animated)

                // Center
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(gaugeColor)
                    Text("/ 100")
                        .font(.system(size: 12))
                        .foregroundColor(.appText.opacity(0.6))
                    Text("Wellness")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.appText.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct WellnessBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wellness Score Breakdown")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appText)
                            .padding(.top, 8)

                        Text("Overall score: **62/100** — Amber zone. Recovery and sleep are the primary drag.")
                            .font(.system(size: 13))
                            .foregroundColor(.appText.opacity(0.7))

                        ForEach(wellnessBreakdownItems) { item in
                            BreakdownRow(item: item)
                        }

                        Text("Tap any metric card on the Home tab for detailed analysis and coaching insights.")
                            .font(.system(size: 12))
                            .foregroundColor(.appText.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
    }
}

private struct BreakdownRow: View {
    let item: WellnessBreakdownItem

    var barColor: Color {
        item.score > 0.75 ? .appMint : item.score >= 0.50 ? .appAccent : .appCoral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appText)
                Spacer()
                Text("\(Int(item.score * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(barColor)
                Text("(weight \(Int(item.weight * 100))%)")
                    .font(.system(size: 11))
                    .foregroundColor(.appText.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appBorder)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * item.score, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}
