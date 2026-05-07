import SwiftUI

struct ProgressView: View {
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @State private var showHistory = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Progress")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Spacer()
                        Button(action: {
                            showHistory = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("History")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Weekly Volume Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weekly Volume")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text(String(format: "%.1fk", workoutData.weeklyStats.totalVolume / 1000))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                Text("lbs")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            Text("lifted this week")
                                .font(.caption)
                                .foregroundColor(.gray)

                            // Weekly volume bar chart — real data
                            WeeklyVolumeChart(workouts: workoutData.recentWorkouts)
                                .frame(height: 120)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    // Personal Records
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Personal Records")
                                .font(.headline)
                                .foregroundColor(.black)

                            Spacer()

                            Text("Predicted")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            if workoutData.personalRecords.isEmpty {
                                Text("No personal records yet")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(12)
                            } else {
                                ForEach(workoutData.personalRecords, id: \.exercise) { pr in
                                    PRCard(
                                        exercise: pr.exercise,
                                        current: pr.current,
                                        predicted: pr.predicted,
                                        unit: "lbs"
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Workout History
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Workouts")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        ForEach(workoutData.recentWorkouts) { workout in
                            HistoryCard(workout: workout)
                                .padding(.horizontal)
                                .onTapGesture { selectedWorkout = workout }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            WorkoutHistoryView()
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutSummarySheet(workout: workout)
        }
    }

    @State private var selectedWorkout: WorkoutSession? = nil
}

struct PRCard: View {
    let exercise: String
    let current: Int
    let predicted: Int
    let unit: String
    @ObservedObject var settings = UserSettings.shared

    var progress: Double {
        Double(current) / Double(predicted)
    }

    var displayCurrent: Int {
        if settings.weightUnit == .metric {
            return Int(Double(current) * 0.453592)
        }
        return current
    }

    var displayPredicted: Int {
        if settings.weightUnit == .metric {
            return Int(Double(predicted) * 0.453592)
        }
        return predicted
    }

    var displayUnit: String {
        settings.weightUnit.rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("+\(displayPredicted - displayCurrent) \(displayUnit)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(displayCurrent)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text("/ \(displayPredicted) \(displayUnit)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct HistoryCard: View {
    let workout: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(workout.duration)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text("min")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                VStack(spacing: 2) {
                    Text("\(workout.exercises.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text("exercises")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
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

struct WeeklyVolumeChart: View {
    let workouts: [WorkoutSession]

    private var dailyVolumes: [(label: String, volume: Double, isToday: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

        return (0..<7).reversed().map { daysBack in
            let day = calendar.date(byAdding: .day, value: -daysBack, to: today)!
            let vol = workouts
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.totalVolume }
            let weekday = calendar.component(.weekday, from: day) - 1
            return (label: weekdaySymbols[weekday], volume: vol, isToday: daysBack == 0)
        }
    }

    var body: some View {
        let maxVol = dailyVolumes.map(\.volume).max() ?? 1
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(dailyVolumes.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.isToday ? Color.blue : (day.volume > 0 ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2)))
                        .frame(height: day.volume > 0 ? max(12, CGFloat(day.volume / maxVol) * 80) : 12)
                    Text(day.label)
                        .font(.caption2)
                        .foregroundColor(day.isToday ? .blue : .gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct WorkoutSummarySheet: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header stats
                        HStack(spacing: 0) {
                            SummaryStatPill(value: formatDate(workout.date), label: "Date")
                            Divider().frame(height: 40)
                            SummaryStatPill(value: "\(workout.duration)", label: "min")
                            Divider().frame(height: 40)
                            SummaryStatPill(value: "\(workout.exercises.count)", label: "exercises")
                            Divider().frame(height: 40)
                            SummaryStatPill(value: "\(workout.totalSets)", label: "sets")
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Exercises
                        ForEach(workout.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.black)

                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Set")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(width: 36, alignment: .leading)
                                        Text("Weight")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Reps")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(width: 44, alignment: .center)
                                        Text("RPE")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(width: 44, alignment: .center)
                                    }
                                    .padding(.horizontal, 4)

                                    Divider()

                                    ForEach(exercise.sets) { set in
                                        HStack {
                                            Text("\(set.setNumber)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .frame(width: 36, alignment: .leading)
                                            Text(set.weight > 0 ? "\(Int(set.weight)) lbs" : "BW")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(set.reps)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.black)
                                                .frame(width: 44, alignment: .center)
                                            if let rpe = set.rpe {
                                                Text(String(format: "%.1f", rpe))
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                    .frame(width: 44, alignment: .center)
                                            } else {
                                                Text("—")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                    .frame(width: 44, alignment: .center)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Total volume
                        HStack {
                            Text("Total Volume")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f lbs", workout.totalVolume))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(workout.type)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct SummaryStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.black)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressView()
}
