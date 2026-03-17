import SwiftUI

struct WorkoutTableView: View {
    @ObservedObject var vm: ActivityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Log")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appText)

            if vm.workouts.isEmpty {
                Text("No workouts recorded.")
                    .font(.system(size: 13))
                    .foregroundColor(.appText.opacity(0.4))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(vm.workouts) { workout in
                    WorkoutRowView(
                        workout: workout,
                        isExpanded: vm.expandedWorkoutID == workout.id,
                        onToggle: { vm.toggleExpand(workout.id) },
                        onEdit:   { vm.startEdit(workout) },
                        onDelete: { vm.confirmDelete(workout.id) }
                    )
                }
            }
        }
    }
}
