import SwiftUI

struct StepsDetailView: View {
    private let hourlyData: [(String, Double)] = [
        ("6am–12pm", 850), ("12pm–6pm", 1900), ("6pm+", 450)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hourly Distribution")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(hourlyData, id: \.0) { label, value in
                    VStack(spacing: 4) {
                        Text("\(Int(value))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appAccent)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appAccent.opacity(0.6))
                            .frame(height: CGFloat(value / 1900) * 60)
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundColor(.appText.opacity(0.5))
                    }
                }
            }
            .frame(height: 90)

            Divider().background(Color.appBorder)

            VStack(spacing: 8) {
                infoRow("Active minutes today", "22 min")
                infoRow("Weekly average", "7,420 steps/day")
                infoRow("Goal", "10,000 steps/day")
            }

            Text("Low step count today is appropriate given Recovery 44/100. Light walking (up to 5,000 steps) supports circulation without adding training stress.")
                .font(.system(size: 12))
                .foregroundColor(.appText.opacity(0.65))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.appText.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.appText)
        }
    }
}
