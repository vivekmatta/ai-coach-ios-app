import SwiftUI

struct WorkoutEditView: View {
    @State var workout: WorkoutEntry
    var onSave: (WorkoutEntry) -> Void
    var onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                Form {
                    Section("Basic Info") {
                        LabeledContent("Date") {
                            TextField("Date", text: $workout.date)
                                .foregroundColor(.appText)
                        }
                        Picker("Type", selection: $workout.type) {
                            ForEach(WorkoutType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        LabeledContent("Label") {
                            TextField("Label", text: $workout.typeLabel)
                                .foregroundColor(.appText)
                        }
                    }

                    Section("Performance") {
                        LabeledContent("Duration") {
                            TextField("Duration", text: $workout.duration)
                                .foregroundColor(.appText)
                        }
                        LabeledContent("Distance") {
                            TextField("Distance", text: $workout.distance)
                                .foregroundColor(.appText)
                        }
                        LabeledContent("Avg HR") {
                            TextField("Avg HR", text: $workout.avgHR)
                                .foregroundColor(.appText)
                        }
                        LabeledContent("Effort") {
                            TextField("Effort", text: $workout.effort)
                                .foregroundColor(.appText)
                        }
                    }

                    Section("Notes") {
                        TextEditor(text: $workout.notes)
                            .frame(minHeight: 80)
                            .foregroundColor(.appText)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.appCoral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(workout)
                        dismiss()
                    }
                    .foregroundColor(.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
