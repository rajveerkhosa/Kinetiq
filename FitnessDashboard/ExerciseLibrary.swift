import SwiftUI

struct APIExercise: Codable {
    let exercise_id: Int
    let exercise_name: String
    let muscle_group: String
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case abs = "Abs"
    case glutes = "Glutes"
    case forearms = "Forearms"
    case cardio = "Cardio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.cooldown"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.mind.and.body"
        case .triceps: return "figure.walk"
        case .legs: return "figure.run"
        case .abs: return "figure.core.training"
        case .glutes: return "figure.stairs"
        case .forearms: return "hand.raised.fill"
        case .cardio: return "heart.fill"
        }
    }
}

struct ExerciseLibraryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExerciseLibraryItem, rhs: ExerciseLibraryItem) -> Bool {
        lhs.id == rhs.id
    }
}

class ExerciseLibrary: ObservableObject {
    static let shared = ExerciseLibrary()

    @Published var exercises: [ExerciseLibraryItem] = []

    func fetchExercises() async {
    guard let url = URL(string: "http://127.0.0.1:8000/exercises") else { return }

    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let apiExercises = try JSONDecoder().decode([APIExercise].self, from: data)

        print("Fetched exercises:", apiExercises.count)

        await MainActor.run {
            self.exercises = apiExercises.map { api in
                let group = MuscleGroup.allCases.first {
                    $0.rawValue.lowercased() == api.muscle_group.lowercased()
                } ?? .chest

                return ExerciseLibraryItem(
                    name: api.exercise_name,
                    muscleGroup: group,
                    equipment: "Unknown"
                )
            }
        }

    } catch {
        print("Error fetching exercises:", error)
    }
}
}
