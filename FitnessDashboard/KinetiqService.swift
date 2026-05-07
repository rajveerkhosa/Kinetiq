import Foundation

// MARK: - KinetiqService
// Networking layer connecting the Swift app to the Python FastAPI ML server.
// The server must be running at baseURL before suggestions will appear.
// Run: cd core/python && uvicorn server:app --port 8000

class KinetiqService {
    static let shared = KinetiqService()

    var baseURL = "https://kinetiq-ml.onrender.com"

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Request / Response Types

    struct ExerciseConfigPayload: Encodable {
        let name: String
        let repRange: [Int]
        let targetRpeRange: [Double]
        let weightIncrementOverride: Double?
        let maxJumpOverride: Double?
        let repsStep: Int
    }

    struct SettingsPayload: Encodable {
        let unit: String
        let lbIncrement: Double
        let kgIncrement: Double
        let maxJumpLb: Double
        let maxJumpKg: Double
        let goal: String
    }

    struct SetLogPayload: Encodable {
        let weight: Double
        let reps: Int
        let rpe: Double
        let ts: String?
    }

    struct SuggestRequest: Encodable {
        let userId: String
        let exercise: ExerciseConfigPayload
        let settings: SettingsPayload
        let lastSet: SetLogPayload
        let history: [SetLogPayload]
        let useMl: Bool
        let debug: Bool
    }

    struct PlateauInfo: Decodable {
        let isPlateau: Bool
        let weeksAtSameWeight: Int
        let rpeTrend: Double
        let recommendation: String
        let explanation: String
    }

    struct RPEReliability: Decodable {
        let score: Double
        let variance: Double
        let nObservations: Int
        let weightInDecisions: Double
    }

    struct SuggestionResponse: Decodable {
        let action: String
        let nextWeight: Double
        let nextReps: Int
        let unit: String
        let explanation: String
        let plateauInfo: PlateauInfo?
        let rpeReliability: RPEReliability?
    }

    // MARK: - Exercise config presets (mirror Python presets.py)

    private static let exerciseConfigs: [String: (repRange: [Int], rpeRange: [Double])] = [
        "Bench Press":          ([5, 8],  [7.0, 9.0]),
        "Barbell Bench Press":  ([5, 8],  [7.0, 9.0]),
        "Overhead Press":       ([5, 8],  [7.0, 9.0]),
        "OHP":                  ([5, 8],  [7.0, 9.0]),
        "Barbell Row":          ([6, 10], [7.0, 9.0]),
        "Bent Over Row":        ([6, 10], [7.0, 9.0]),
        "Squat":                ([5, 8],  [7.0, 9.0]),
        "Back Squat":           ([5, 8],  [7.0, 9.0]),
        "Deadlift":             ([3, 6],  [7.0, 9.0]),
        "Romanian Deadlift":    ([8, 12], [7.0, 9.0]),
        "Leg Press":            ([8, 12], [7.0, 9.0]),
        "Dumbbell Curl":        ([8, 12], [7.0, 9.0]),
        "Barbell Curl":         ([8, 12], [7.0, 9.0]),
        "Tricep Pushdown":      ([10, 15],[7.0, 9.0]),
        "Tricep Extension":     ([10, 15],[7.0, 9.0]),
        "Dumbbell Fly":         ([10, 15],[7.0, 9.0]),
        "Lat Pulldown":         ([8, 12], [7.0, 9.0]),
        "Seated Cable Row":     ([8, 12], [7.0, 9.0]),
        "Dumbbell Shoulder Press": ([8, 12], [7.0, 9.0]),
    ]

    private static let defaultConfig: (repRange: [Int], rpeRange: [Double]) = ([8, 12], [7.0, 9.0])

    private func exerciseConfig(for name: String) -> (repRange: [Int], rpeRange: [Double]) {
        Self.exerciseConfigs[name] ?? Self.defaultConfig
    }

    // MARK: - Goal mapping

    private func goalString() -> String {
        switch UserProfile.shared.primaryGoal {
        case .strength:         return "strength"
        case .muscleHypertrophy: return "hypertrophy"
        case .both, .none:      return "both"
        }
    }

    // MARK: - Unit mapping

    private func unitString() -> String {
        UserSettings.shared.weightUnit == .metric ? "kg" : "lb"
    }

    // MARK: - Main suggest call

    func suggest(
        exerciseName: String,
        lastSet: ExerciseSet,
        history: [ExerciseSet],
        userId: String = "default"
    ) async throws -> SuggestionResponse {
        guard let url = URL(string: "\(baseURL)/suggest") else {
            throw URLError(.badURL)
        }

        let config = exerciseConfig(for: exerciseName)
        let unit = unitString()
        let goal = goalString()
        let settings = UserSettings.shared

        let settingsPayload = SettingsPayload(
            unit: unit,
            lbIncrement: settings.weightUnit == .metric ? 0 : 2.5,
            kgIncrement: settings.weightUnit == .metric ? 1.25 : 0,
            maxJumpLb: 10.0,
            maxJumpKg: 5.0,
            goal: goal
        )

        let exercisePayload = ExerciseConfigPayload(
            name: exerciseName,
            repRange: config.repRange,
            targetRpeRange: config.rpeRange,
            weightIncrementOverride: nil,
            maxJumpOverride: nil,
            repsStep: 1
        )

        guard let rpe = lastSet.rpe else {
            throw URLError(.unknown)
        }

        let lastSetPayload = SetLogPayload(
            weight: lastSet.weight,
            reps: lastSet.reps,
            rpe: rpe,
            ts: nil
        )

        // Only include history sets that have RPE (pre-feature sets don't)
        let historyPayload = history.compactMap { set -> SetLogPayload? in
            guard let setRpe = set.rpe else { return nil }
            return SetLogPayload(weight: set.weight, reps: set.reps, rpe: setRpe, ts: nil)
        }

        let request_body = SuggestRequest(
            userId: userId,
            exercise: exercisePayload,
            settings: settingsPayload,
            lastSet: lastSetPayload,
            history: historyPayload,
            useMl: true,
            debug: false
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 35.0
        request.httpBody = try encoder.encode(request_body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(SuggestionResponse.self, from: data)
    }
}
