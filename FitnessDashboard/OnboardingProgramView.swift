import SwiftUI

struct OnboardingProgramView: View {
    @ObservedObject var profile = UserProfile.shared
    @Binding var currentStep: OnboardingStep
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let totalPages = 4 // Goal, Frequency, Duration, Split
    private let hapticImpact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Paged content
                TabView(selection: $currentPage) {
                    // Page 0: Primary Goal
                    PrimaryGoalPage(profile: profile)
                        .tag(0)

                    // Page 1: Workouts Per Week
                    WorkoutsPerWeekPage(profile: profile)
                        .tag(1)

                    // Page 2: Session Duration
                    SessionDurationPage(profile: profile)
                        .tag(2)

                    // Page 3: Workout Split
                    WorkoutSplitPage(profile: profile)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    hapticImpact.impactOccurred()
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(16)
                        }
                    }

                    Button(action: {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage < totalPages - 1 ? "Continue" : "Complete Setup")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(canContinue ? Color.white : Color.white.opacity(0.3))
                            .cornerRadius(16)
                    }
                    .disabled(!canContinue)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
if isLoading {
    ProgressView()
        .tint(.white)
        .padding(.bottom, 10)
}

if let error = errorMessage {
    Text(error)
        .font(.caption)
        .foregroundColor(.red)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
}
        }
    }

    private var canContinue: Bool {
        switch currentPage {
        case 0: return profile.primaryGoal != nil
        case 1: return profile.workoutsPerWeek != nil
        case 2: return profile.sessionDurationMinutes != nil
        case 3: return profile.workoutSplit != nil
        default: return false
        }
    }

private func completeOnboarding() {
    isLoading = true
    errorMessage = nil

    Task {
        do {
            guard let fullName = profile.fullName else {
                errorMessage = "Missing profile information. Please go back and complete all fields."
                isLoading = false
                return
            }

            let sex = profile.sex?.rawValue ?? "other"
            let heightCm = profile.heightCm ?? 170.0
            let weightKg = profile.weightKg ?? 70.0
            let experience = profile.liftingExperience?.rawValue ?? "beginner"
            let age = profile.age ?? 25

            // Convert height from cm to ft and inches
            let totalInches = heightCm / 2.54
            let heightFt = Int(totalInches / 12)
            let heightIn = Int(totalInches.truncatingRemainder(dividingBy: 12))

            // Convert weight from kg to lbs
            let weightLb = weightKg * 2.20462

            // Parse name
            let nameParts = fullName.split(separator: " ").map(String.init)
            let firstName = nameParts.first ?? fullName
            let lastName = nameParts.count > 1 ? nameParts.last ?? "" : ""

            // Today's date as journey started
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let journeyStarted = formatter.string(from: Date())

            // Build request body
            let body: [String: Any] = [
                "username": profile.fullName ?? firstName,
                "email": UserDefaults.standard.string(forKey: "pendingEmail") ?? "",
                "password": UserDefaults.standard.string(forKey: "pendingPassword") ?? "",
                "first_name": firstName,
                "middle_name": NSNull(),
                "last_name": lastName,
                "age": age,
                "sex": sex,
                "height_ft": heightFt,
                "height_in": heightIn,
                "weight_lb": weightLb,
                "experience_level": experience,
                "journey_started": journeyStarted
            ]

            guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/register") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Save user_id from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userId = json["user_id"] as? Int {
                    UserDefaults.standard.set(userId, forKey: "user_id")
                }

                // Clean up temp credentials
                UserDefaults.standard.removeObject(forKey: "pendingEmail")
                UserDefaults.standard.removeObject(forKey: "pendingPassword")

                await MainActor.run {
                    profile.hasCompletedOnboarding = true
                    currentStep = .complete
                }
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let detail = json?["detail"] as? String ?? "Registration failed"
                await MainActor.run {
                    errorMessage = detail
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}





}

// MARK: - Program Pages

struct PrimaryGoalPage: View {
    @ObservedObject var profile: UserProfile

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Primary Goal")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("What's your main fitness goal?")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.primaryGoal = goal
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Icon circle
                                Circle()
                                    .fill(profile.primaryGoal == goal ? Color.black : Color.white.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: goalIcon(for: goal))
                                            .font(.system(size: 22))
                                            .foregroundColor(profile.primaryGoal == goal ? .white : .white.opacity(0.6))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.rawValue)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(profile.primaryGoal == goal ? .black : .white)

                                    Text(goalDescription(for: goal))
                                        .font(.system(size: 14))
                                        .foregroundColor(profile.primaryGoal == goal ? .black.opacity(0.6) : .white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if profile.primaryGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.black)
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(20)
                            .background(profile.primaryGoal == goal ? Color.white : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    private func goalIcon(for goal: FitnessGoal) -> String {
        switch goal {
        case .muscleHypertrophy:
            return "figure.strengthtraining.traditional"
        case .strength:
            return "dumbbell.fill"
        case .both:
            return "bolt.fill"
        }
    }

    private func goalDescription(for goal: FitnessGoal) -> String {
        switch goal {
        case .muscleHypertrophy:
            return "Build muscle mass and size with higher volume training"
        case .strength:
            return "Maximize strength gains with lower reps and heavier weights"
        case .both:
            return "Balanced approach combining muscle growth and strength"
        }
    }
}

struct WorkoutsPerWeekPage: View {
    @ObservedObject var profile: UserProfile
    @State private var selectedFrequency: Int = 4

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Training Frequency")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("How many times per week can you train?")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                // Display current selection
                Text("\(selectedFrequency) days per week")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)

                // Slider
                Slider(value: Binding(
                    get: { Double(selectedFrequency) },
                    set: { selectedFrequency = Int($0) }
                ), in: 2...7, step: 1)
                    .accentColor(.white)
                    .padding(.horizontal, 40)

                // Labels
                HStack {
                    Text("2")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("7")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 40)

                Text(frequencyAdvice(for: selectedFrequency))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
            .onChange(of: selectedFrequency) { _, newValue in
                profile.workoutsPerWeek = newValue
            }

            Spacer()
        }
        .onAppear {
            if let existing = profile.workoutsPerWeek {
                selectedFrequency = existing
            } else {
                profile.workoutsPerWeek = selectedFrequency
            }
        }
    }

    private func frequencyAdvice(for days: Int) -> String {
        switch days {
        case 2...3:
            return "Great for beginners or those with limited time. Focus on full body workouts."
        case 4...5:
            return "Ideal for most people. Allows for good muscle recovery and growth."
        case 6...7:
            return "Advanced frequency. Ensure proper recovery and nutrition."
        default:
            return ""
        }
    }
}

struct SessionDurationPage: View {
    @ObservedObject var profile: UserProfile
    @State private var selectedDuration: Int = 60

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Session Duration")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("How long can you train per session?")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                // Display current selection
                Text("\(selectedDuration) minutes")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)

                // Slider
                Slider(value: Binding(
                    get: { Double(selectedDuration) },
                    set: { selectedDuration = Int($0) }
                ), in: 30...120, step: 15)
                    .accentColor(.white)
                    .padding(.horizontal, 40)

                // Labels
                HStack {
                    Text("30 min")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("2 hours")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 40)

                Text(durationAdvice(for: selectedDuration))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
            .onChange(of: selectedDuration) { _, newValue in
                profile.sessionDurationMinutes = newValue
            }

            Spacer()
        }
        .onAppear {
            if let existing = profile.sessionDurationMinutes {
                selectedDuration = existing
            } else {
                profile.sessionDurationMinutes = selectedDuration
            }
        }
    }

    private func durationAdvice(for minutes: Int) -> String {
        switch minutes {
        case 0...45:
            return "Quick and efficient. Perfect for busy schedules."
        case 46...75:
            return "Ideal duration for most training programs."
        case 76...120:
            return "Extended sessions. Great for detailed, high-volume training."
        default:
            return ""
        }
    }
}

struct WorkoutSplitPage: View {
    @ObservedObject var profile: UserProfile

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Workout Split")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Choose your training split")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(WorkoutSplit.allCases, id: \.self) { split in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.workoutSplit = split
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Icon circle
                                Circle()
                                    .fill(profile.workoutSplit == split ? Color.black : Color.white.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: splitIcon(for: split))
                                            .font(.system(size: 22))
                                            .foregroundColor(profile.workoutSplit == split ? .white : .white.opacity(0.6))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(split.rawValue)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(profile.workoutSplit == split ? .black : .white)

                                        Text("\(split.daysPerWeek)x")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(profile.workoutSplit == split ? .black.opacity(0.5) : .white.opacity(0.4))
                                    }

                                    Text(split.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(profile.workoutSplit == split ? .black.opacity(0.6) : .white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if profile.workoutSplit == split {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.black)
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(20)
                            .background(profile.workoutSplit == split ? Color.white : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    private func splitIcon(for split: WorkoutSplit) -> String {
        switch split {
        case .upperLower:
            return "arrow.up.arrow.down.circle.fill"
        case .fullBody:
            return "figure.mixed.cardio"
        case .broSplit:
            return "calendar.circle.fill"
        case .arnold:
            return "flame.fill"
        case .ppl:
            return "arrow.3.trianglepath"
        case .pplArnold:
            return "star.circle.fill"
        }
    }
}

#Preview {
    OnboardingProgramView(currentStep: .constant(.program))
}
