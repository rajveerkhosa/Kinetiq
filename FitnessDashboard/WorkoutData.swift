import Foundation

// Models for workout data
struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let type: String
    let exercises: [Exercise]
    let duration: Int // in minutes

    init(date: Date, type: String, exercises: [Exercise], duration: Int) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.exercises = exercises
        self.duration = duration
    }

    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + (set.weight * Double(set.reps))
            }
        }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

struct PersonalRecord: Codable {
    let exercise: String
    var current: Int
    var predicted: Int
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let sets: [ExerciseSet]
    let muscleGroup: String

    init(name: String, sets: [ExerciseSet], muscleGroup: String) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.muscleGroup = muscleGroup
    }
}

struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    let weight: Double // in lbs
    let reps: Int
    let setNumber: Int
    var rpe: Double?   // optional — sets logged before RPE feature was added will be nil

    init(weight: Double, reps: Int, setNumber: Int, rpe: Double? = nil) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
        self.rpe = rpe
    }
}

// Sample workout data
class WorkoutDataStore: ObservableObject {
    static let shared = WorkoutDataStore()
    private let profile = UserProfile.shared

    @Published var personalRecords: [PersonalRecord] {
        didSet {
            savePersonalRecords()
        }
    }

    @Published var recentWorkouts: [WorkoutSession] {
        didSet {
            saveRecentWorkouts()
        }
    }

    /// Last ML suggestion per exercise name (in-memory only — goes stale after workouts).
    @Published var lastSuggestions: [String: KinetiqService.SuggestionResponse] = [:]

    var nextWorkout: String {
        // Get the next workout based on user's selected workout split
        let workoutList = getWorkoutRotation()

        // Find last workout type from history
        if let lastWorkout = recentWorkouts.first {
            if let lastIndex = workoutList.firstIndex(of: lastWorkout.type) {
                let nextIndex = (lastIndex + 1) % workoutList.count
                return workoutList[nextIndex]
            }
        }

        // Default to first workout in rotation
        return workoutList.first ?? "Full Body"
    }

    let nextWorkoutDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

    // Get workout rotation based on user's selected split
    func getWorkoutRotation() -> [String] {
        guard let split = profile.workoutSplit else {
            return ["Full Body"] // Default
        }

        switch split {
        case .upperLower:
            return ["Upper Body A", "Lower Body A", "Upper Body B", "Lower Body B"]
        case .fullBody:
            return ["Full Body A", "Full Body B", "Full Body C"]
        case .broSplit:
            return ["Chest Day", "Back Day", "Legs Day", "Shoulders Day", "Arms Day"]
        case .arnold:
            return ["Chest/Back", "Shoulders/Arms", "Legs", "Chest/Back", "Shoulders/Arms", "Legs"]
        case .ppl:
            return ["Push", "Pull", "Legs", "Push", "Pull", "Legs"]
        case .pplArnold:
            return ["Push", "Pull", "Legs", "Chest/Back", "Shoulders/Arms", "Legs"]
        }
    }

    var weeklyStats: (workouts: Int, totalSets: Int, totalVolume: Double) {
        let workoutsThisWeek = recentWorkouts.filter { workout in
            Calendar.current.isDate(workout.date, equalTo: Date(), toGranularity: .weekOfYear)
        }

        let sets = workoutsThisWeek.reduce(0) { $0 + $1.totalSets }
        let volume = workoutsThisWeek.reduce(0) { $0 + $1.totalVolume }

        return (workoutsThisWeek.count, sets, volume)
    }

    var currentStreak: Int {
        guard !recentWorkouts.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Get unique workout dates (sorted most recent first)
        let workoutDates = Set(recentWorkouts.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        // Check if there's a workout today or yesterday to start the streak
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        if !workoutDates.contains(currentDate) && !workoutDates.contains(yesterday) {
            return 0 // Streak is broken
        }

        // Count consecutive days
        for date in workoutDates {
            if date == currentDate || date == calendar.date(byAdding: .day, value: -1, to: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }

        return streak
    }

    func saveWorkout(_ session: WorkoutSession) {
        recentWorkouts.insert(session, at: 0) // Add to beginning (most recent)

        // Keep only last 50 workouts to avoid excessive data
        if recentWorkouts.count > 50 {
            recentWorkouts = Array(recentWorkouts.prefix(50))
        }
    }

    /// All persisted sets for a given exercise across all workout history.
    /// Used to build the history payload for the ML API.
    func history(for exerciseName: String) -> [ExerciseSet] {
        recentWorkouts
            .flatMap { $0.exercises }
            .filter { $0.name.lowercased() == exerciseName.lowercased() }
            .flatMap { $0.sets }
    }

    /// Best estimated 1RM for an exercise using Epley formula (sets with 1–12 reps only).
    func e1rm(for exerciseName: String) -> Double? {
        let estimates = history(for: exerciseName)
            .filter { $0.reps > 0 && $0.reps <= 12 && $0.weight > 0 }
            .map { $0.weight * (1 + Double($0.reps) / 30.0) }
        return estimates.max()
    }

    /// E1RM per workout session (for trend chart), sorted oldest → newest.
    func e1rmTrend(for exerciseName: String) -> [(date: Date, e1rm: Double)] {
        var result: [(date: Date, e1rm: Double)] = []
        for session in recentWorkouts {
            let sets = session.exercises
                .filter { $0.name.lowercased() == exerciseName.lowercased() }
                .flatMap { $0.sets }
                .filter { $0.reps > 0 && $0.reps <= 12 && $0.weight > 0 }
            let estimates = sets.map { $0.weight * (1 + Double($0.reps) / 30.0) }
            if let best = estimates.max() {
                result.append((date: session.date, e1rm: best))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Store last ML suggestion for an exercise (used by StrengthView ML card).
    func storeSuggestion(_ suggestion: KinetiqService.SuggestionResponse, for exerciseName: String) {
        lastSuggestions[exerciseName] = suggestion
    }

    /// Weight + reps history for an exercise, joined with parent session date.
    /// Returns tuples sorted oldest → newest.
    func weightHistory(for exerciseName: String) -> [(date: Date, weight: Double, reps: Int)] {
        var result: [(date: Date, weight: Double, reps: Int)] = []
        for session in recentWorkouts {
            for exercise in session.exercises where exercise.name.lowercased() == exerciseName.lowercased() {
                for set in exercise.sets where set.weight > 0 && set.reps > 0 {
                    result.append((date: session.date, weight: set.weight, reps: set.reps))
                }
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Human-readable summary of the last performance for an exercise.
    /// Returns a string like "185 lbs × 8, 7, 6" or nil if no history.
    func lastPerformanceString(for exerciseName: String, unit: String = "lbs") -> String? {
        let pastSets = recentWorkouts
            .flatMap { $0.exercises }
            .first { $0.name.lowercased() == exerciseName.lowercased() }
            .map { $0.sets }

        guard let sets = pastSets, !sets.isEmpty else { return nil }

        let weight = sets.first.map { Int($0.weight) } ?? 0
        let repsStr = sets.map { String($0.reps) }.joined(separator: ", ")
        return "\(weight) \(unit) × \(repsStr)"
    }

    init() {
        // Load personal records from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "personalRecords"),
           let records = try? JSONDecoder().decode([PersonalRecord].self, from: data) {
            self.personalRecords = records
        } else {
            // Default personal records for new users
            self.personalRecords = [
                PersonalRecord(exercise: "Bench Press", current: 185, predicted: 195),
                PersonalRecord(exercise: "Squat", current: 225, predicted: 240),
                PersonalRecord(exercise: "Deadlift", current: 315, predicted: 335),
                PersonalRecord(exercise: "Overhead Press", current: 95, predicted: 105)
            ]
        }

        // Load recent workouts from UserDefaults (with sample data fallback)
        if let data = UserDefaults.standard.data(forKey: "recentWorkouts"),
           let workouts = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            self.recentWorkouts = workouts
        } else {
            // Sample data for first launch
            self.recentWorkouts = WorkoutDataStore.sampleWorkouts
        }
    }

    private func savePersonalRecords() {
        if let encoded = try? JSONEncoder().encode(personalRecords) {
            UserDefaults.standard.set(encoded, forKey: "personalRecords")
        }
    }

    private func saveRecentWorkouts() {
        if let encoded = try? JSONEncoder().encode(recentWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "recentWorkouts")
        }
    }

    func resetAllData() {
        recentWorkouts = []
        personalRecords = []
        UserDefaults.standard.removeObject(forKey: "personalRecords")
        UserDefaults.standard.removeObject(forKey: "recentWorkouts")
    }

    // MARK: - Sample data (used only on first launch when no persisted data exists)
    private static var sampleWorkouts: [WorkoutSession] {
        [
            WorkoutSession(
                date: Date(),
                type: "Upper Body",
                exercises: [
                    Exercise(
                        name: "Bench Press",
                        sets: [
                            ExerciseSet(weight: 185, reps: 8, setNumber: 1),
                            ExerciseSet(weight: 185, reps: 7, setNumber: 2),
                            ExerciseSet(weight: 185, reps: 6, setNumber: 3),
                            ExerciseSet(weight: 165, reps: 10, setNumber: 4)
                        ],
                        muscleGroup: "Chest"
                    ),
                    Exercise(
                        name: "Barbell Row",
                        sets: [
                            ExerciseSet(weight: 155, reps: 10, setNumber: 1),
                            ExerciseSet(weight: 155, reps: 9, setNumber: 2),
                            ExerciseSet(weight: 155, reps: 8, setNumber: 3),
                            ExerciseSet(weight: 135, reps: 12, setNumber: 4)
                        ],
                        muscleGroup: "Back"
                    ),
                    Exercise(
                        name: "Overhead Press",
                        sets: [
                            ExerciseSet(weight: 95, reps: 10, setNumber: 1),
                            ExerciseSet(weight: 95, reps: 9, setNumber: 2),
                            ExerciseSet(weight: 95, reps: 8, setNumber: 3)
                        ],
                        muscleGroup: "Shoulders"
                    ),
                    Exercise(
                        name: "Dumbbell Curl",
                        sets: [
                            ExerciseSet(weight: 30, reps: 12, setNumber: 1),
                            ExerciseSet(weight: 30, reps: 11, setNumber: 2),
                            ExerciseSet(weight: 30, reps: 10, setNumber: 3)
                        ],
                        muscleGroup: "Biceps"
                    ),
                    Exercise(
                        name: "Tricep Pushdown",
                        sets: [
                            ExerciseSet(weight: 50, reps: 15, setNumber: 1),
                            ExerciseSet(weight: 50, reps: 14, setNumber: 2),
                            ExerciseSet(weight: 50, reps: 12, setNumber: 3)
                        ],
                        muscleGroup: "Triceps"
                    )
                ],
                duration: 75
            ),
            WorkoutSession(
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                type: "Lower Body",
                exercises: [
                    Exercise(
                        name: "Squat",
                        sets: [
                            ExerciseSet(weight: 225, reps: 8, setNumber: 1),
                            ExerciseSet(weight: 225, reps: 7, setNumber: 2),
                            ExerciseSet(weight: 225, reps: 6, setNumber: 3),
                            ExerciseSet(weight: 205, reps: 10, setNumber: 4)
                        ],
                        muscleGroup: "Legs"
                    ),
                    Exercise(
                        name: "Romanian Deadlift",
                        sets: [
                            ExerciseSet(weight: 185, reps: 10, setNumber: 1),
                            ExerciseSet(weight: 185, reps: 9, setNumber: 2),
                            ExerciseSet(weight: 185, reps: 8, setNumber: 3)
                        ],
                        muscleGroup: "Hamstrings"
                    ),
                    Exercise(
                        name: "Leg Press",
                        sets: [
                            ExerciseSet(weight: 320, reps: 12, setNumber: 1),
                            ExerciseSet(weight: 320, reps: 11, setNumber: 2),
                            ExerciseSet(weight: 320, reps: 10, setNumber: 3)
                        ],
                        muscleGroup: "Legs"
                    )
                ],
                duration: 65
            )
        ]
    }
}
