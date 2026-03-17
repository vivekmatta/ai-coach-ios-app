import SwiftUI

struct StressDetailView: View {
    private let timeline: [(String, String, Color)] = [
        ("Morning",   "High",     .appCoral),
        ("Midday",    "High",     .appCoral),
        ("Afternoon", "Moderate", .appAccent),
        ("Evening",   "Moderate", .appAccent),
        ("Night",     "—",        Color.appText.opacity(0.4))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stress Timeline Today")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)

            HStack(spacing: 6) {
                ForEach(timeline, id: \.0) { period, level, color in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                        Text(level)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(color)
                        Text(period)
                            .font(.system(size: 9))
                            .foregroundColor(.appText.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider().background(Color.appBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Contributing Factors")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                ForEach([
                    "Involuntary 5am wake-up (1.5hrs early)",
                    "HRV suppression below 40ms",
                    "Elevated resting HR (+12%)",
                    "Accumulated work stress from past week"
                ], id: \.self) { factor in
                    Label(factor, systemImage: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appText.opacity(0.7))
                        .labelStyle(BulletLabelStyle())
                }
            }
        }
    }
}
