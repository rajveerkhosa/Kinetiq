import SwiftUI

struct KinetiqView: View {
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @State private var showWorkoutOverview = false
    @State private var showActiveWorkout = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Next Workout Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Next Session")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.nextWorkout)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal)

                        Button(action: {
                            showWorkoutOverview = true
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Workout")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Stats Grid
                    HStack(spacing: 16) {
                        StatCard(icon: "dumbbell.fill", title: "Total", value: "\(workoutData.recentWorkouts.count)", subtitle: "Workouts")
                        StatCard(icon: "calendar", title: "Week", value: "\(workoutData.weeklyStats.workouts)", subtitle: "This week")
                    }
                    .padding(.horizontal)

                    HStack(spacing: 16) {
                        StatCard(icon: "figure.strengthtraining.traditional", title: "Sets", value: "\(workoutData.weeklyStats.totalSets)", subtitle: "This week")
                        StatCard(icon: "scalemass.fill", title: "Volume", value: String(format: "%.1fk", workoutData.weeklyStats.totalVolume / 1000), subtitle: "lbs lifted")
                    }
                    .padding(.horizontal)

                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        ForEach(workoutData.recentWorkouts.prefix(3)) { workout in
                            WorkoutCard(workout: workout)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showWorkoutOverview) {
            WorkoutOverviewView(
                isPresented: $showWorkoutOverview,
                showActiveWorkout: $showActiveWorkout,
                workoutType: workoutData.nextWorkout,
                exercises: loadWorkoutExercises(for: workoutData.nextWorkout)
            )
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(isPresented: $showActiveWorkout, workoutType: workoutData.nextWorkout)
        }
    }

    func loadWorkoutExercises(for workoutType: String) -> [WorkoutExercise] {
        if workoutType.contains("Upper") {
            return [
                WorkoutExercise(name: "Bench Press", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "185 lbs × 8, 7, 6"),
                WorkoutExercise(name: "Barbell Row", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "165 lbs × 8, 8, 7"),
                WorkoutExercise(name: "Overhead Press", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "95 lbs × 8, 7, 6"),
                WorkoutExercise(name: "Dumbbell Curl", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "30 lbs × 12, 10"),
                WorkoutExercise(name: "Tricep Pushdown", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "50 lbs × 12, 12")
            ]
        } else {
            return [
                WorkoutExercise(name: "Squat", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "225 lbs × 8, 7, 6"),
                WorkoutExercise(name: "Romanian Deadlift", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "185 lbs × 10, 9, 8"),
                WorkoutExercise(name: "Leg Press", sets: [
                    ExerciseSetInput(weight: "", reps: "", completed: false),
                    ExerciseSetInput(weight: "", reps: "", completed: false)
                ], lastPerformance: "360 lbs × 12, 10")
            ]
        }
    }
}

struct WorkoutCard: View {
    let workout: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type)
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(formatDate(workout.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(workout.duration) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Text("\(workout.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Divider()

            // Exercise list
            VStack(spacing: 8) {
                ForEach(workout.exercises) { exercise in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Text(exercise.name)
                            .font(.subheadline)
                            .foregroundColor(.black)

                        Spacer()

                        Text("\(exercise.sets.count) sets")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Button(action: {}) {
                HStack {
                    Text("View Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
    }
}

#Preview {
    KinetiqView()
}
