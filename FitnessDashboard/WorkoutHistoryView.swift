import SwiftUI

struct WorkoutHistoryView: View {
    let workoutData = WorkoutDataStore.shared

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Text("Workout History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 16) {
                        ForEach(workoutData.recentWorkouts) { workout in
                            WorkoutHistoryCard(workout: workout)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

struct WorkoutHistoryCard: View {
    let workout: WorkoutSession
    @ObservedObject var settings = UserSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text(formatDate(workout.date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(workout.duration) min")
                            .font(.subheadline)
                    }
                    .foregroundColor(.black)

                    Text("\(workout.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Divider()

            // Exercise Summary
            VStack(spacing: 12) {
                ForEach(workout.exercises) { exercise in
                    HStack(spacing: 12) {
                        // Exercise icon
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 36, height: 36)

                            Image(systemName: "dumbbell.fill")
                                .font(.caption)
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)

                            Text(exerciseSummary(exercise))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Volume
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatVolume(calculateVolume(exercise)))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)

                            Text("volume")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today at " + formatTime(date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at " + formatTime(date)
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    func exerciseSummary(_ exercise: Exercise) -> String {
        let setCount = exercise.sets.count
        let reps = exercise.sets.map { String($0.reps) }.joined(separator: ", ")
        return "\(setCount) sets × \(reps) reps"
    }

    func calculateVolume(_ exercise: Exercise) -> Double {
        var totalVolume: Double = 0
        for set in exercise.sets {
            totalVolume += set.weight * Double(set.reps)
        }
        return totalVolume
    }

    func formatVolume(_ volumeInLbs: Double) -> String {
        let convertedVolume: Double
        let unit: String

        if settings.weightUnit == .metric {
            // Convert lbs to kg
            convertedVolume = volumeInLbs * 0.453592
            unit = "kg"
        } else {
            convertedVolume = volumeInLbs
            unit = "lbs"
        }

        return String(format: "%.0f %@", convertedVolume, unit)
    }
}

#Preview {
    WorkoutHistoryView()
}
