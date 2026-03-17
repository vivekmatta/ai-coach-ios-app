import SwiftUI

struct ActivityView: View {
    @StateObject private var vm = ActivityViewModel()

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Summary strip
                    HStack(spacing: 0) {
                        summaryCard(title: "Workouts", value: "\(vm.totalWorkouts)", icon: "figure.run")
                        Divider().background(Color.appBorder).frame(height: 40)
                        summaryCard(title: "Distance", value: vm.totalDistanceMiles, icon: "map")
                        Divider().background(Color.appBorder).frame(height: 40)
                        summaryCard(title: "Active Time", value: vm.totalActiveTime, icon: "clock")
                    }
                    .background(Color.appCard)
                    .cornerRadius(AppRadius.card)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))

                    // Frequency calendar
                    FrequencyChartView()

                    // Workout table
                    WorkoutTableView(vm: vm)

                    // Health log (collapsible)
                    HealthLogView(vm: vm)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .alert("Delete Workout?", isPresented: $vm.showDeleteConfirm) {
            Button("Delete", role: .destructive) { vm.executeDelete() }
            Button("Cancel", role: .cancel) { vm.cancelDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $vm.editingWorkout) { workout in
            WorkoutEditView(workout: workout) { updated in
                vm.saveEdit(updated)
            } onCancel: {
                vm.cancelEdit()
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func summaryCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.appAccent)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.appText)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.appText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
