import SwiftUI

struct WorkoutRowView: View {
    let workout: WorkoutEntry
    let isExpanded: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    // Type badge
                    Text(workout.typeLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(workout.type.color)
                        .cornerRadius(6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.date)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appText)
                        Text("\(workout.duration) · \(workout.distance)")
                            .font(.system(size: 11))
                            .foregroundColor(.appText.opacity(0.55))
                    }

                    Spacer()

                    Text(workout.effort)
                        .font(.system(size: 11))
                        .foregroundColor(.appText.opacity(0.5))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.appText.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().background(Color.appBorder)

                    VStack(alignment: .leading, spacing: 6) {
                        detailRow("Avg HR",    workout.avgHR)
                        detailRow("Effort",    workout.effort)
                        detailRow("Distance",  workout.distance)
                        detailRow("Duration",  workout.duration)

                        Text("Notes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appText.opacity(0.5))
                        Text(workout.notes)
                            .font(.system(size: 12))
                            .foregroundColor(.appText.opacity(0.8))
                    }

                    HStack(spacing: 10) {
                        Spacer()
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appCoral)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.appCard)
        .cornerRadius(AppRadius.card)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.appText.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appText)
        }
    }
}
