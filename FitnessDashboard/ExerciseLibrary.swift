import SwiftUI

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

class ExerciseLibrary {
    static let shared = ExerciseLibrary()

    let exercises: [ExerciseLibraryItem] = [
        // CHEST
        ExerciseLibraryItem(name: "Barbell Bench Press", muscleGroup: .chest, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Incline Barbell Bench Press", muscleGroup: .chest, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Decline Barbell Bench Press", muscleGroup: .chest, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Dumbbell Bench Press", muscleGroup: .chest, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Incline Dumbbell Press", muscleGroup: .chest, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Decline Dumbbell Press", muscleGroup: .chest, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Dumbbell Flyes", muscleGroup: .chest, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Incline Dumbbell Flyes", muscleGroup: .chest, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Cable Flyes", muscleGroup: .chest, equipment: "Cable"),
        ExerciseLibraryItem(name: "Chest Dips", muscleGroup: .chest, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Push-Ups", muscleGroup: .chest, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Machine Chest Press", muscleGroup: .chest, equipment: "Machine"),
        ExerciseLibraryItem(name: "Pec Deck", muscleGroup: .chest, equipment: "Machine"),
        ExerciseLibraryItem(name: "Landmine Press", muscleGroup: .chest, equipment: "Barbell"),

        // BACK
        ExerciseLibraryItem(name: "Deadlift", muscleGroup: .back, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Barbell Row", muscleGroup: .back, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Pendlay Row", muscleGroup: .back, equipment: "Barbell"),
        ExerciseLibraryItem(name: "T-Bar Row", muscleGroup: .back, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Dumbbell Row", muscleGroup: .back, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Single Arm Dumbbell Row", muscleGroup: .back, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Pull-Ups", muscleGroup: .back, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Chin-Ups", muscleGroup: .back, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Lat Pulldown", muscleGroup: .back, equipment: "Cable"),
        ExerciseLibraryItem(name: "Cable Row", muscleGroup: .back, equipment: "Cable"),
        ExerciseLibraryItem(name: "Face Pulls", muscleGroup: .back, equipment: "Cable"),
        ExerciseLibraryItem(name: "Seated Cable Row", muscleGroup: .back, equipment: "Cable"),
        ExerciseLibraryItem(name: "Machine Row", muscleGroup: .back, equipment: "Machine"),
        ExerciseLibraryItem(name: "Rack Pulls", muscleGroup: .back, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Hyperextensions", muscleGroup: .back, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Superman", muscleGroup: .back, equipment: "Bodyweight"),

        // SHOULDERS
        ExerciseLibraryItem(name: "Overhead Press", muscleGroup: .shoulders, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Seated Overhead Press", muscleGroup: .shoulders, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Dumbbell Shoulder Press", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Arnold Press", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Lateral Raises", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Front Raises", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Reverse Flyes", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Cable Lateral Raises", muscleGroup: .shoulders, equipment: "Cable"),
        ExerciseLibraryItem(name: "Upright Row", muscleGroup: .shoulders, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Machine Shoulder Press", muscleGroup: .shoulders, equipment: "Machine"),
        ExerciseLibraryItem(name: "Shrugs", muscleGroup: .shoulders, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Barbell Shrugs", muscleGroup: .shoulders, equipment: "Barbell"),

        // BICEPS
        ExerciseLibraryItem(name: "Barbell Curl", muscleGroup: .biceps, equipment: "Barbell"),
        ExerciseLibraryItem(name: "EZ Bar Curl", muscleGroup: .biceps, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Dumbbell Curl", muscleGroup: .biceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Hammer Curl", muscleGroup: .biceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Preacher Curl", muscleGroup: .biceps, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Concentration Curl", muscleGroup: .biceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Cable Curl", muscleGroup: .biceps, equipment: "Cable"),
        ExerciseLibraryItem(name: "Incline Dumbbell Curl", muscleGroup: .biceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Spider Curl", muscleGroup: .biceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "21s", muscleGroup: .biceps, equipment: "Barbell"),

        // TRICEPS
        ExerciseLibraryItem(name: "Close Grip Bench Press", muscleGroup: .triceps, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Tricep Dips", muscleGroup: .triceps, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Skull Crushers", muscleGroup: .triceps, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Overhead Tricep Extension", muscleGroup: .triceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Cable Tricep Pushdown", muscleGroup: .triceps, equipment: "Cable"),
        ExerciseLibraryItem(name: "Rope Tricep Pushdown", muscleGroup: .triceps, equipment: "Cable"),
        ExerciseLibraryItem(name: "Tricep Kickbacks", muscleGroup: .triceps, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Diamond Push-Ups", muscleGroup: .triceps, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Dumbbell Skull Crushers", muscleGroup: .triceps, equipment: "Dumbbell"),

        // LEGS
        ExerciseLibraryItem(name: "Barbell Squat", muscleGroup: .legs, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Front Squat", muscleGroup: .legs, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Goblet Squat", muscleGroup: .legs, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Bulgarian Split Squat", muscleGroup: .legs, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Leg Press", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Leg Extension", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Leg Curl", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Romanian Deadlift", muscleGroup: .legs, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Lunges", muscleGroup: .legs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Walking Lunges", muscleGroup: .legs, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Hack Squat", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Calf Raises", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Seated Calf Raises", muscleGroup: .legs, equipment: "Machine"),
        ExerciseLibraryItem(name: "Box Jumps", muscleGroup: .legs, equipment: "Bodyweight"),

        // GLUTES
        ExerciseLibraryItem(name: "Hip Thrust", muscleGroup: .glutes, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Glute Bridge", muscleGroup: .glutes, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Cable Kickbacks", muscleGroup: .glutes, equipment: "Cable"),
        ExerciseLibraryItem(name: "Hip Abduction Machine", muscleGroup: .glutes, equipment: "Machine"),
        ExerciseLibraryItem(name: "Step-Ups", muscleGroup: .glutes, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Donkey Kicks", muscleGroup: .glutes, equipment: "Bodyweight"),

        // ABS
        ExerciseLibraryItem(name: "Crunches", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Plank", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Side Plank", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Russian Twists", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Leg Raises", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Hanging Leg Raises", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Bicycle Crunches", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Mountain Climbers", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Ab Wheel Rollout", muscleGroup: .abs, equipment: "Equipment"),
        ExerciseLibraryItem(name: "Cable Crunches", muscleGroup: .abs, equipment: "Cable"),
        ExerciseLibraryItem(name: "Decline Sit-Ups", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "V-Ups", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Dead Bug", muscleGroup: .abs, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Pallof Press", muscleGroup: .abs, equipment: "Cable"),

        // FOREARMS
        ExerciseLibraryItem(name: "Wrist Curls", muscleGroup: .forearms, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Reverse Wrist Curls", muscleGroup: .forearms, equipment: "Barbell"),
        ExerciseLibraryItem(name: "Farmer's Walk", muscleGroup: .forearms, equipment: "Dumbbell"),
        ExerciseLibraryItem(name: "Plate Pinch", muscleGroup: .forearms, equipment: "Equipment"),

        // CARDIO
        ExerciseLibraryItem(name: "Running", muscleGroup: .cardio, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Cycling", muscleGroup: .cardio, equipment: "Machine"),
        ExerciseLibraryItem(name: "Rowing Machine", muscleGroup: .cardio, equipment: "Machine"),
        ExerciseLibraryItem(name: "Jump Rope", muscleGroup: .cardio, equipment: "Equipment"),
        ExerciseLibraryItem(name: "Burpees", muscleGroup: .cardio, equipment: "Bodyweight"),
        ExerciseLibraryItem(name: "Stair Climber", muscleGroup: .cardio, equipment: "Machine"),
        ExerciseLibraryItem(name: "Elliptical", muscleGroup: .cardio, equipment: "Machine"),
        ExerciseLibraryItem(name: "Battle Ropes", muscleGroup: .cardio, equipment: "Equipment"),
    ]

    func exercisesForMuscleGroup(_ muscleGroup: MuscleGroup) -> [ExerciseLibraryItem] {
        exercises.filter { $0.muscleGroup == muscleGroup }
    }
}
