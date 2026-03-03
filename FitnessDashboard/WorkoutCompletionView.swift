import SwiftUI

struct WorkoutCompletionView: View {
    let workoutType: String
    let duration: TimeInterval
    let exercises: [WorkoutExercise]
    let onDismiss: () -> Void

    @ObservedObject var settings = UserSettings.shared

    var totalSets: Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { !$0.weight.isEmpty && !$0.reps.isEmpty }.count
        }
    }

    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                guard !set.weight.isEmpty, !set.reps.isEmpty,
                      let weight = Double(set.weight),
                      let reps = Int(set.reps) else {
                    return setTotal
                }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    var displayVolume: String {
        let volume = totalVolume
        if settings.weightUnit == .metric {
            return String(format: "%.1f kg", volume * 0.453592)
        }
        return String(format: "%.1f lbs", volume)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Success Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.green)
                }

                // Title
                VStack(spacing: 8) {
                    Text("Workout Complete!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Great job on finishing your workout")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Stats Cards
                VStack(spacing: 16) {
                    // Duration & Exercises Row
                    HStack(spacing: 16) {
                        CompletionStatCard(
                            icon: "clock.fill",
                            value: formattedDuration,
                            label: "Duration"
                        )

                        CompletionStatCard(
                            icon: "dumbbell.fill",
                            value: "\(exercises.count)",
                            label: exercises.count == 1 ? "Exercise" : "Exercises"
                        )
                    }

                    // Sets & Volume Row
                    HStack(spacing: 16) {
                        CompletionStatCard(
                            icon: "list.bullet",
                            value: "\(totalSets)",
                            label: totalSets == 1 ? "Set" : "Sets"
                        )

                        CompletionStatCard(
                            icon: "chart.bar.fill",
                            value: displayVolume,
                            label: "Total Volume"
                        )
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                // Done Button
                Button(action: {
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

struct CompletionStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview {
    WorkoutCompletionView(
        workoutType: "Upper Body",
        duration: 3600,
        exercises: [],
        onDismiss: {}
    )
}
