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

                            // Simple bar chart
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<7) { day in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(day < 2 ? Color.blue : Color.gray.opacity(0.2))
                                            .frame(height: day == 0 ? 80 : (day == 1 ? 60 : 20))

                                        Text(["M", "T", "W", "T", "F", "S", "S"][day])
                                            .font(.caption2)
                                            .foregroundColor(day < 2 ? .blue : .gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
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
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            WorkoutHistoryView()
        }
    }
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

#Preview {
    ProgressView()
}
