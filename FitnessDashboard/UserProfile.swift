import Foundation

// User profile data model
class UserProfile: ObservableObject {
    static let shared = UserProfile()

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var fullName: String? {
        didSet {
            if let name = fullName {
                UserDefaults.standard.set(name, forKey: "userFullName")
            }
        }
    }

    // Basics
    @Published var sex: Sex? {
        didSet {
            if let sex = sex {
                UserDefaults.standard.set(sex.rawValue, forKey: "userSex")
            }
        }
    }

    @Published var birthDate: Date? {
        didSet {
            if let date = birthDate {
                UserDefaults.standard.set(date, forKey: "userBirthDate")
            }
        }
    }

    @Published var heightCm: Double? {
        didSet {
            if let height = heightCm {
                UserDefaults.standard.set(height, forKey: "userHeightCm")
            }
        }
    }

    @Published var weightKg: Double? {
        didSet {
            if let weight = weightKg {
                UserDefaults.standard.set(weight, forKey: "userWeightKg")
            }
        }
    }

    @Published var bodyFatLevel: BodyFatLevel? {
        didSet {
            if let level = bodyFatLevel {
                UserDefaults.standard.set(level.rawValue, forKey: "userBodyFatLevel")
            }
        }
    }

    @Published var liftingExperience: ExperienceLevel? {
        didSet {
            if let level = liftingExperience {
                UserDefaults.standard.set(level.rawValue, forKey: "userLiftingExperience")
            }
        }
    }

    @Published var cardioLevel: ExperienceLevel? {
        didSet {
            if let level = cardioLevel {
                UserDefaults.standard.set(level.rawValue, forKey: "userCardioLevel")
            }
        }
    }

    // Program
    @Published var primaryGoal: FitnessGoal? {
        didSet {
            if let goal = primaryGoal {
                UserDefaults.standard.set(goal.rawValue, forKey: "userPrimaryGoal")
            }
        }
    }

    @Published var workoutsPerWeek: Int? {
        didSet {
            if let count = workoutsPerWeek {
                UserDefaults.standard.set(count, forKey: "userWorkoutsPerWeek")
            }
        }
    }

    @Published var sessionDurationMinutes: Int? {
        didSet {
            if let duration = sessionDurationMinutes {
                UserDefaults.standard.set(duration, forKey: "userSessionDuration")
            }
        }
    }

    @Published var workoutSplit: WorkoutSplit? {
        didSet {
            if let split = workoutSplit {
                UserDefaults.standard.set(split.rawValue, forKey: "userWorkoutSplit")
            }
        }
    }

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.fullName = UserDefaults.standard.string(forKey: "userFullName")

        if let sexRaw = UserDefaults.standard.string(forKey: "userSex") {
            self.sex = Sex(rawValue: sexRaw)
        }

        if let date = UserDefaults.standard.object(forKey: "userBirthDate") as? Date {
            self.birthDate = date
        }

        let heightCm = UserDefaults.standard.double(forKey: "userHeightCm")
        self.heightCm = heightCm > 0 ? heightCm : nil

        let weightKg = UserDefaults.standard.double(forKey: "userWeightKg")
        self.weightKg = weightKg > 0 ? weightKg : nil

        if let levelRaw = UserDefaults.standard.string(forKey: "userBodyFatLevel") {
            self.bodyFatLevel = BodyFatLevel(rawValue: levelRaw)
        }

        if let levelRaw = UserDefaults.standard.string(forKey: "userLiftingExperience") {
            self.liftingExperience = ExperienceLevel(rawValue: levelRaw)
        }

        if let levelRaw = UserDefaults.standard.string(forKey: "userCardioLevel") {
            self.cardioLevel = ExperienceLevel(rawValue: levelRaw)
        }

        if let goalRaw = UserDefaults.standard.string(forKey: "userPrimaryGoal") {
            self.primaryGoal = FitnessGoal(rawValue: goalRaw)
        }

        let workoutsPerWeek = UserDefaults.standard.integer(forKey: "userWorkoutsPerWeek")
        self.workoutsPerWeek = workoutsPerWeek > 0 ? workoutsPerWeek : nil

        let sessionDuration = UserDefaults.standard.integer(forKey: "userSessionDuration")
        self.sessionDurationMinutes = sessionDuration > 0 ? sessionDuration : nil

        if let splitRaw = UserDefaults.standard.string(forKey: "userWorkoutSplit") {
            self.workoutSplit = WorkoutSplit(rawValue: splitRaw)
        }
    }

    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }

    // Reset all profile data and trigger onboarding again
    func resetPlan() {
        // Clear all profile data
        self.sex = nil
        self.birthDate = nil
        self.heightCm = nil
        self.weightKg = nil
        self.bodyFatLevel = nil
        self.liftingExperience = nil
        self.cardioLevel = nil
        self.primaryGoal = nil
        self.workoutsPerWeek = nil
        self.sessionDurationMinutes = nil
        self.workoutSplit = nil
        self.hasCompletedOnboarding = false
        // Note: fullName is kept, only cleared on new account

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "userSex")
        UserDefaults.standard.removeObject(forKey: "userBirthDate")
        UserDefaults.standard.removeObject(forKey: "userHeightCm")
        UserDefaults.standard.removeObject(forKey: "userWeightKg")
        UserDefaults.standard.removeObject(forKey: "userBodyFatLevel")
        UserDefaults.standard.removeObject(forKey: "userLiftingExperience")
        UserDefaults.standard.removeObject(forKey: "userCardioLevel")
        UserDefaults.standard.removeObject(forKey: "userPrimaryGoal")
        UserDefaults.standard.removeObject(forKey: "userWorkoutsPerWeek")
        UserDefaults.standard.removeObject(forKey: "userSessionDuration")
        UserDefaults.standard.removeObject(forKey: "userWorkoutSplit")
    }
}

// Enums for profile options
enum Sex: String, CaseIterable {
    case male = "Male"
    case female = "Female"
}

enum BodyFatLevel: String, CaseIterable {
    case veryLean = "Very Lean"
    case lean = "Lean"
    case average = "Average"
    case aboveAverage = "Above Average"
    case high = "High"

    var description: String {
        switch self {
        case .veryLean: return "6-10% (Male) / 14-18% (Female)"
        case .lean: return "11-14% (Male) / 19-22% (Female)"
        case .average: return "15-19% (Male) / 23-27% (Female)"
        case .aboveAverage: return "20-24% (Male) / 28-32% (Female)"
        case .high: return "25%+ (Male) / 33%+ (Female)"
        }
    }
}

enum ExperienceLevel: String, CaseIterable {
    case none = "None"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var description: String {
        switch self {
        case .none:
            return "Currently not lifting"
        case .beginner:
            return "Lifting for the past year or less"
        case .intermediate:
            return "Lifting for more than the past year, but less than 4 years"
        case .advanced:
            return "Lifting for the past 4 years or more"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "circle"
        case .beginner:
            return "figure.walk"
        case .intermediate:
            return "figure.run"
        case .advanced:
            return "figure.strengthtraining.traditional"
        }
    }
}

enum FitnessGoal: String, CaseIterable {
    case muscleHypertrophy = "Muscle Hypertrophy"
    case strength = "Strength"
    case both = "Both"
}
