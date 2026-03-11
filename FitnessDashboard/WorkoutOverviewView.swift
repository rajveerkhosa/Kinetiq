import SwiftUI

struct WorkoutOverviewView: View {
    @Binding var isPresented: Bool
    @Binding var showActiveWorkout: Bool
    let workoutType: String
    @State var exercises: [WorkoutExercise]
    var completedExercises: Set<Int> = []
    var currentExercise: Int? = nil
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                            } else {
                                editMode = .active
                            }
                        }
                    }) {
                        Text(editMode == .active ? "Done" : "Reorder")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(editMode == .active ? .green : .white)
                    }
                }
                .padding()

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 24) {
                        // Title
                        VStack(spacing: 8) {
                            Text(workoutType)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("\(exercises.count) Exercises")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)

                        // Exercise List
                        VStack(spacing: 16) {
                            ForEach(exercises.indices, id: \.self) { index in
                                ExerciseOverviewCard(
                                    exercise: exercises[index],
                                    isCompleted: completedExercises.contains(index),
                                    isInProgress: currentExercise == index,
                                    isEditing: editMode == .active
                                )
                            }
                            .onMove { source, destination in
                                exercises.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                        .padding(.horizontal)
                        .environment(\.editMode, $editMode)

                        // Start Button
                        if currentExercise == nil {
                            Button(action: {
                                isPresented = false
                                showActiveWorkout = true
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Workout")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        } else {
                            Button(action: {
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Back to Workout")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }
}

struct ExerciseOverviewCard: View {
    let exercise: WorkoutExercise
    let isCompleted: Bool
    let isInProgress: Bool
    var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Drag handle when editing
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.title3)
            }
            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(statusColor)
                } else if isInProgress {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(.white)

                if let lastPerformance = exercise.lastPerformance {
                    Text(lastPerformance)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Text("\(exercise.sets.count) sets")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if isInProgress {
                Text("IN PROGRESS")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            } else if isCompleted {
                Text("COMPLETED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.white.opacity(isInProgress ? 0.15 : 0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isInProgress ? statusColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    var statusColor: Color {
        if isCompleted {
            return .green
        } else if isInProgress {
            return .orange
        } else {
            return .white
        }
    }
}

#Preview {
    WorkoutOverviewView(
        isPresented: .constant(true),
        showActiveWorkout: .constant(false),
        workoutType: "Upper Body",
        exercises: [
            WorkoutExercise(name: "Bench Press", sets: [
                ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
            ], lastPerformance: "185 lbs × 8, 7, 6"),
            WorkoutExercise(name: "Barbell Row", sets: [
                ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
            ], lastPerformance: "165 lbs × 8, 8, 7")
        ]
    )
}
