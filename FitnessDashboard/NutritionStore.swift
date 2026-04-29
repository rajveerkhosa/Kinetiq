import Foundation
import SwiftUI

struct FoodEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var brand: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var servingSize: String
    var quantity: Double
    var timestamp: Date
}

struct DailyGoals {
    var calories: Int
    var protein: Int
    var fat: Int
    var carbs: Int
}

class NutritionStore: ObservableObject {
    static let shared = NutritionStore()

    @Published var entriesByDate: [String: [FoodEntry]] = [:]

    private let directory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("nutrition", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadAll()
    }

    // MARK: - Goals

    func dailyGoals(for profile: UserProfile) -> DailyGoals {
        let weightKg = profile.weightKg ?? 70.0
        let heightCm = profile.heightCm ?? 170.0
        let age = Double(profile.age ?? 25)
        let sex = profile.sex ?? .female
        let workoutsPerWeek = profile.workoutsPerWeek ?? 3

        // Mifflin-St Jeor BMR
        let bmr: Double
        switch sex {
        case .male:
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        case .female:
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161
        }

        // Activity multiplier from workouts/week
        let multiplier: Double
        switch workoutsPerWeek {
        case 0...1: multiplier = 1.2
        case 2...3: multiplier = 1.375
        case 4...5: multiplier = 1.55
        default:    multiplier = 1.725
        }

        let tdee = bmr * multiplier
        // All current goals are muscle building — add ~300 surplus
        let targetCalories = Int(tdee + 300)

        // Macros
        let weightLb = weightKg * 2.20462
        let proteinG = Int(weightLb * 1.0)          // 1g per lb
        let fatG = Int(Double(targetCalories) * 0.25 / 9)
        let carbCals = Double(targetCalories) - Double(proteinG * 4) - Double(fatG * 9)
        let carbG = Int(max(carbCals / 4, 0))

        return DailyGoals(calories: targetCalories, protein: proteinG, fat: fatG, carbs: carbG)
    }

    // MARK: - Entries

    func entries(for date: Date) -> [FoodEntry] {
        entriesByDate[key(for: date)] ?? []
    }

    func add(_ entry: FoodEntry, for date: Date) {
        let k = key(for: date)
        var list = entriesByDate[k] ?? []
        list.append(entry)
        list.sort { $0.timestamp < $1.timestamp }
        entriesByDate[k] = list
        save(key: k)
        syncDailyTotals(for: date)
        syncFoodEntry(entry, for: date)
    }

    func delete(_ entry: FoodEntry, for date: Date) {
        let k = key(for: date)
        entriesByDate[k]?.removeAll { $0.id == entry.id }
        save(key: k)
        syncDailyTotals(for: date)
    }

    // MARK: - Backend Sync

    private func syncDailyTotals(for date: Date) {
        let userId = UserDefaults.standard.integer(forKey: "user_id")
        guard userId > 0 else { return }
        let t = totals(for: date)
        let dateStr = key(for: date)
        Task {
            guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/nutrition/log") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "user_id": userId,
                "log_date": dateStr,
                "calories": t.calories,
                "protein_g": t.protein,
                "carbs_g": t.carbs,
                "fats_g": t.fat
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    private func syncFoodEntry(_ entry: FoodEntry, for date: Date) {
        let userId = UserDefaults.standard.integer(forKey: "user_id")
        guard userId > 0 else { return }
        let dateStr = key(for: date)
        Task {
            guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/nutrition/entries") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "user_id": userId,
                "log_date": dateStr,
                "food_name": entry.name,
                "brand": entry.brand,
                "calories": entry.calories * entry.quantity,
                "protein_g": entry.protein * entry.quantity,
                "carbs_g": entry.carbs * entry.quantity,
                "fats_g": entry.fat * entry.quantity,
                "serving_size": entry.servingSize,
                "quantity": entry.quantity
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    func totals(for date: Date) -> (calories: Double, protein: Double, fat: Double, carbs: Double) {
        let list = entries(for: date)
        return (
            list.reduce(0) { $0 + $1.calories * $1.quantity },
            list.reduce(0) { $0 + $1.protein * $1.quantity },
            list.reduce(0) { $0 + $1.fat * $1.quantity },
            list.reduce(0) { $0 + $1.carbs * $1.quantity }
        )
    }

    // MARK: - Persistence

    private func key(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func fileURL(key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }

    private func save(key: String) {
        guard let entries = entriesByDate[key] else { return }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL(key: key))
        }
    }

    private func loadAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" {
            let k = file.deletingPathExtension().lastPathComponent
            if let data = try? Data(contentsOf: file),
               let entries = try? JSONDecoder().decode([FoodEntry].self, from: data) {
                entriesByDate[k] = entries
            }
        }
    }
}
