import SwiftUI

struct ServerPlan: Identifiable {
    let id: Int
    let name: String
    let isActive: Bool
}

struct KinetiqView: View {
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @ObservedObject var workoutManager = ActiveWorkoutManager.shared
    @State private var showWorkoutOverview = false
    @State private var plans: [ServerPlan] = []
    @State private var isLoadingPlans = false
    @State private var showCreatePlan = false

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
                            workoutManager.workoutType = workoutData.nextWorkout
                            workoutManager.isActive = true
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Quick Start")
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

                    // My Plans
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Plans")
                                .font(.headline)
                                .foregroundColor(.black)
                            Spacer()
                            Button(action: { showCreatePlan = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("New")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.black)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)

                        if isLoadingPlans {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding()
                        } else if plans.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "list.bullet.clipboard")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No plans yet — tap New to create one")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 24)
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            ForEach(plans) { plan in
                                PlanCard(plan: plan) {
                                    UserDefaults.standard.set(plan.id, forKey: "active_plan_id")
                                    workoutManager.workoutType = plan.name
                                    workoutManager.isActive = true
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

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
        .sheet(isPresented: $showCreatePlan) {
            WorkoutPlanBuilderView()
        }
        .task { await fetchPlans() }
        .onReceive(NotificationCenter.default.publisher(for: .planCreated)) { _ in
            Task { await fetchPlans() }
        }
    }

    func fetchPlans() async {
        let userId = UserDefaults.standard.integer(forKey: "user_id")
        guard userId > 0,
              let url = URL(string: "https://kinetiq-dzfm.onrender.com/plans/\(userId)") else { return }
        isLoadingPlans = true
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = json["plans"] as? [[String: Any]] {
            let fetched = list.compactMap { p -> ServerPlan? in
                guard let id = p["plan_id"] as? Int, let name = p["plan_name"] as? String else { return nil }
                let active = p["active_flag"] as? Bool ?? false
                return ServerPlan(id: id, name: name, isActive: active)
            }
            await MainActor.run {
                plans = fetched
                isLoadingPlans = false
            }
        } else {
            await MainActor.run { isLoadingPlans = false }
        }
    }

    func loadWorkoutExercises(for workoutType: String) -> [WorkoutExercise] {
        let store = WorkoutDataStore.shared
        let unit = UserSettings.shared.weightUnit.rawValue

        func makeExercise(_ name: String, setCount: Int) -> WorkoutExercise {
            let lastPerf = store.lastPerformanceString(for: name, unit: unit)
            let sets = (0..<setCount).map { _ in
                ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
            }
            return WorkoutExercise(name: name, sets: sets, lastPerformance: lastPerf)
        }

        if workoutType.contains("Upper") {
            return [
                makeExercise("Bench Press", setCount: 3),
                makeExercise("Barbell Row", setCount: 3),
                makeExercise("Overhead Press", setCount: 3),
                makeExercise("Dumbbell Curl", setCount: 2),
                makeExercise("Tricep Pushdown", setCount: 2)
            ]
        } else {
            return [
                makeExercise("Squat", setCount: 3),
                makeExercise("Romanian Deadlift", setCount: 3),
                makeExercise("Leg Press", setCount: 2)
            ]
        }
    }
}

struct WorkoutCard: View {
    let workout: WorkoutSession
    @State private var showSummary = false

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

            Button(action: { showSummary = true }) {
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
        .sheet(isPresented: $showSummary) {
            WorkoutSummarySheet(workout: workout)
        }
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

struct PlanCard: View {
    let plan: ServerPlan
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(plan.isActive ? Color.black : Color.black.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                    .foregroundColor(plan.isActive ? .white : .black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.headline)
                    .foregroundColor(.black)
                if plan.isActive {
                    Text("Active plan")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: onStart) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.black)
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

extension Notification.Name {
    static let planCreated = Notification.Name("planCreated")
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
