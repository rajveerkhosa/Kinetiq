import SwiftUI

struct AccountView: View {
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @ObservedObject var settings = UserSettings.shared
    @ObservedObject var profile = UserProfile.shared
    @State private var showHistory = false
    @State private var showWorkoutBuilder = false
    @State private var showRestTimerSettings = false
    @State private var showResetAlert = false
    @State private var showResetPlanAlert = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Profile Section
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )

                        Text(profile.fullName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)

                        Text("\(workoutData.recentWorkouts.count) workouts completed")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Stats")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            StatRow(label: "Total Workouts", value: "\(workoutData.recentWorkouts.count)")
                            Divider().padding(.leading, 20)
                            StatRow(label: "This Month", value: "\(workoutData.weeklyStats.workouts)")
                            Divider().padding(.leading, 20)
                            StatRow(label: "Current Streak", value: "\(workoutData.currentStreak) \(workoutData.currentStreak == 1 ? "Day" : "Days")")
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            showHistory = true
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.black)
                                Text("Workout History")
                                    .foregroundColor(.black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        Button(action: {
                            showWorkoutBuilder = true
                        }) {
                            HStack {
                                Image(systemName: "dumbbell.fill")
                                    .foregroundColor(.black)
                                Text("Create Workout Plan")
                                    .foregroundColor(.black)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Preferences
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preferences")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            // Unit System Toggle
                            HStack(spacing: 16) {
                                Image(systemName: "ruler.fill")
                                    .frame(width: 24)
                                    .foregroundColor(.black)

                                Text("Use Metric System")
                                    .foregroundColor(.black)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { settings.weightUnit == .metric },
                                    set: { newValue in
                                        settings.weightUnit = newValue ? .metric : .imperial
                                    }
                                ))
                                .labelsHidden()
                            }
                            .padding()

                            Divider().padding(.leading, 56)

                            // Rest Timer Setting
                            Button(action: {
                                showRestTimerSettings = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "timer")
                                        .frame(width: 24)
                                        .foregroundColor(.black)

                                    Text("Rest Timer Duration")
                                        .foregroundColor(.black)

                                    Spacer()

                                    Text("\(settings.restTimerDuration)s")
                                        .foregroundColor(.gray)

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Plan Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Training Plan")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        Button(action: {
                            showResetPlanAlert = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .frame(width: 24)
                                    .foregroundColor(.orange)

                                Text("Reset Training Plan")
                                    .foregroundColor(.black)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Data Management
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Management")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        Button(action: {
                            showResetAlert = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "arrow.counterclockwise")
                                    .frame(width: 24)
                                    .foregroundColor(.gray)

                                Text("Reset All Data")
                                    .foregroundColor(.black)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            WorkoutHistoryView()
        }
        .sheet(isPresented: $showWorkoutBuilder) {
            WorkoutPlanBuilderView()
        }
        .sheet(isPresented: $showRestTimerSettings) {
            RestTimerSettingsView()
        }
        .alert("Reset All Data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your workout history, settings, and data. This action cannot be undone.")
        }
        .alert("Reset Training Plan?", isPresented: $showResetPlanAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Plan", role: .destructive) {
                profile.resetPlan()
            }
        } message: {
            Text("This will reset your training plan settings and you'll go through the setup again. Your workout history will not be affected.")
        }
    }

    func resetAllData() {
        // Reset workout data
        workoutData.resetAllData()

        // Reset settings to defaults
        settings.weightUnit = .imperial
        settings.restTimerDuration = 120

        // Reset user profile and trigger onboarding
        profile.resetPlan()

        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    AccountView()
}
