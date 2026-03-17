import SwiftUI

struct FrequencyChartView: View {
    private let calendar = AppConstants.freqCalendar

    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Frequency — Last 14 Days")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appText)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(calendar.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 3) {
                        dot(for: entry.type)
                        Text(shortDate(entry.date))
                            .font(.system(size: 8))
                            .foregroundColor(.appText.opacity(0.4))
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                ForEach([
                    (WorkoutType.run,   "Run"),
                    (WorkoutType.swim,  "Swim"),
                    (WorkoutType.brick, "Brick"),
                    (WorkoutType.yoga,  "Yoga")
                ], id: \.1) { type, label in
                    HStack(spacing: 4) {
                        Circle().fill(type.color).frame(width: 8, height: 8)
                        Text(label).font(.system(size: 10)).foregroundColor(.appText.opacity(0.5))
                    }
                }
                HStack(spacing: 4) {
                    Circle().strokeBorder(Color.appBorder, lineWidth: 1.5).frame(width: 8, height: 8)
                    Text("Rest").font(.system(size: 10)).foregroundColor(.appText.opacity(0.5))
                }
            }
        }
        .padding(14)
        .background(Color.appCard)
        .cornerRadius(AppRadius.card)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func dot(for type: WorkoutType?) -> some View {
        if let type = type {
            Circle()
                .fill(type.color)
                .frame(width: 22, height: 22)
        } else {
            Circle()
                .strokeBorder(Color.appBorder, lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
    }

    private func shortDate(_ s: String) -> String {
        let parts = s.split(separator: " ")
        guard parts.count == 2 else { return s }
        return String(parts[1])
    }
}
