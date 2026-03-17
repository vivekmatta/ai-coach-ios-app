import Foundation
import Combine
import SwiftUI

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var workouts: [WorkoutEntry] = AppConstants.workouts
    @Published var expandedWorkoutID: Int? = nil
    @Published var editingWorkout: WorkoutEntry? = nil
    @Published var showDeleteConfirm: Bool = false
    @Published var pendingDeleteID: Int? = nil
    @Published var healthLogExpanded: Bool = false

    let healthLog = AppConstants.healthLog

    // MARK: – Summary
    var totalWorkouts: Int { workouts.count }
    var totalDistanceMiles: String {
        let distances: [Double] = [9.2, 6.1, 0, 28.4+3.8, 4.2, 0, 0, 3.6, 0]
        let total = distances.reduce(0, +)
        return String(format: "%.1f mi", total)
    }
    var totalActiveTime: String { "7h 55m" }

    // MARK: – Actions
    func toggleExpand(_ id: Int) {
        expandedWorkoutID = expandedWorkoutID == id ? nil : id
    }

    func startEdit(_ workout: WorkoutEntry) {
        editingWorkout = workout
    }

    func saveEdit(_ updated: WorkoutEntry) {
        if let idx = workouts.firstIndex(where: { $0.id == updated.id }) {
            workouts[idx] = updated
        }
        editingWorkout = nil
    }

    func cancelEdit() {
        editingWorkout = nil
    }

    func confirmDelete(_ id: Int) {
        pendingDeleteID = id
        showDeleteConfirm = true
    }

    func executeDelete() {
        if let id = pendingDeleteID {
            workouts.removeAll { $0.id == id }
            if expandedWorkoutID == id { expandedWorkoutID = nil }
        }
        pendingDeleteID = nil
        showDeleteConfirm = false
    }

    func cancelDelete() {
        pendingDeleteID = nil
        showDeleteConfirm = false
    }
}
