import SwiftUI

private let lightBg = Color(red: 0.95, green: 0.95, blue: 0.97)

struct FoodSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let calories: Double    // per serving
    let protein: Double
    let fat: Double
    let carbs: Double
    let servingSizeG: Double
}

class FoodSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [FoodSearchResult] = []
    @Published var isLoading = false
    @Published var hasSearched = false

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; hasSearched = false; return }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            do {
                let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
                guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/nutrition/search?q=\(encoded)") else { return }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let items = json?["items"] as? [[String: Any]] ?? []

                let parsed: [FoodSearchResult] = items.compactMap { item in
                    guard let name = item["name"] as? String else { return nil }
                    let cal  = item["calories"] as? Double ?? 0
                    let prot = item["protein_g"] as? Double ?? 0
                    let fat  = item["fat_total_g"] as? Double ?? 0
                    let carb = item["carbohydrates_total_g"] as? Double ?? 0
                    let srvG = item["serving_size_g"] as? Double ?? 100
                    guard cal > 0 || prot > 0 else { return nil }
                    return FoodSearchResult(name: name, calories: cal, protein: prot, fat: fat, carbs: carb, servingSizeG: srvG)
                }

                await MainActor.run {
                    self.results = parsed
                    self.isLoading = false
                    self.hasSearched = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.isLoading = false; self.hasSearched = true }
            }
        }
    }
}

struct FoodSearchView: View {
    let date: Date
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = FoodSearchViewModel()
    @ObservedObject private var store = NutritionStore.shared
    @State private var showManualEntry = false

    var body: some View {
        ZStack {
            lightBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.07))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Add Food")
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: { showManualEntry = true }) {
                        Text("Manual")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("e.g. \"2 eggs\" or \"cup of oatmeal\"", text: $vm.query)
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .onSubmit { vm.search() }
                    if !vm.query.isEmpty {
                        Button(action: { vm.query = ""; vm.results = []; vm.hasSearched = false }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                // Hint
                if !vm.hasSearched && vm.query.isEmpty {
                    Text("Describe what you ate in plain English")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(.black)
                    Spacer()
                } else if vm.hasSearched && vm.results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No results for \"\(vm.query)\"")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        Text("Try being more specific, e.g. \"grilled chicken breast\"")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button(action: { showManualEntry = true }) {
                            Text("Add manually")
                                .font(.subheadline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.08))
                                .cornerRadius(10)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vm.results) { result in
                                FoodResultRow(result: result, date: date, onAdded: { dismiss() })
                                if result.id != vm.results.last?.id {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onChange(of: vm.query) { _, _ in vm.search() }
        .sheet(isPresented: $showManualEntry) {
            ManualFoodEntryView(date: date, prefillName: vm.query) { dismiss() }
        }
    }
}

struct FoodResultRow: View {
    let result: FoodSearchResult
    let date: Date
    let onAdded: () -> Void
    @ObservedObject private var store = NutritionStore.shared
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(lightBg).frame(width: 46, height: 46)
                    Image(systemName: "fork.knife").foregroundColor(.gray).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name.capitalized)
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.black).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(Int(result.calories)) kcal").foregroundColor(.orange).fontWeight(.medium)
                        Text("·").foregroundColor(.gray)
                        Text("\(Int(result.protein))P  \(Int(result.fat))F  \(Int(result.carbs))C")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                    Text("per \(Int(result.servingSizeG))g serving")
                        .font(.caption2).foregroundColor(.gray.opacity(0.6))
                }
                Spacer()
                Button(action: {
                    store.add(FoodEntry(
                        name: result.name.capitalized, brand: "",
                        calories: result.calories, protein: result.protein,
                        fat: result.fat, carbs: result.carbs,
                        servingSize: "\(Int(result.servingSizeG))g", quantity: 1, timestamp: Date()
                    ), for: date)
                    onAdded()
                }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            FoodDetailView(result: result, date: date, onAdded: onAdded)
        }
    }
}

struct FoodDetailView: View {
    let result: FoodSearchResult
    let date: Date
    let onAdded: () -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = NutritionStore.shared
    @State private var quantity: Double = 1.0
    @State private var quantityText = "1"

    private var scaled: (cal: Double, p: Double, f: Double, c: Double) {
        (result.calories * quantity, result.protein * quantity, result.fat * quantity, result.carbs * quantity)
    }

    var body: some View {
        ZStack {
            lightBg.ignoresSafeArea()
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text(result.name.capitalized)
                    .font(.title3).fontWeight(.bold).foregroundColor(.black)
                    .multilineTextAlignment(.center).padding(.horizontal)

                Text("Per \(Int(result.servingSizeG))g serving")
                    .font(.caption).foregroundColor(.gray)

                HStack(spacing: 16) {
                    macroPill(label: "CAL", value: Int(scaled.cal), color: .orange)
                    macroPill(label: "P",   value: Int(scaled.p),   color: Color(red: 0.9, green: 0.3, blue: 0.3))
                    macroPill(label: "F",   value: Int(scaled.f),   color: Color(red: 0.85, green: 0.65, blue: 0.1))
                    macroPill(label: "C",   value: Int(scaled.c),   color: Color(red: 0.2, green: 0.7, blue: 0.4))
                }

                VStack(spacing: 8) {
                    Text("Number of servings").font(.caption).foregroundColor(.gray)
                    HStack(spacing: 16) {
                        Button(action: { if quantity > 0.5 { quantity = max(0.1, quantity - 0.5); quantityText = formatQ(quantity) } }) {
                            Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.black.opacity(0.7))
                        }
                        TextField("1", text: $quantityText)
                            .keyboardType(.decimalPad).foregroundColor(.black)
                            .font(.title2.bold()).multilineTextAlignment(.center).frame(width: 70)
                            .onChange(of: quantityText) { _, val in if let d = Double(val), d > 0 { quantity = d } }
                        Button(action: { quantity += 0.5; quantityText = formatQ(quantity) }) {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.black.opacity(0.7))
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(14)
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    store.add(FoodEntry(
                        name: result.name.capitalized, brand: "",
                        calories: result.calories, protein: result.protein,
                        fat: result.fat, carbs: result.carbs,
                        servingSize: "\(Int(result.servingSizeG))g", quantity: quantity, timestamp: Date()
                    ), for: date)
                    dismiss(); onAdded()
                }) {
                    Text("Add to Log")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.black).cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }

    private func formatQ(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    @ViewBuilder
    private func macroPill(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.headline).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(width: 60, height: 60)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

struct ManualFoodEntryView: View {
    let date: Date
    var prefillName: String = ""
    let onAdded: () -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = NutritionStore.shared

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var servingSize = "1 serving"

    var canSave: Bool { !name.isEmpty && Double(calories) != nil }

    var body: some View {
        ZStack {
            lightBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                    Spacer()
                    Text("Manual Entry").font(.headline).foregroundColor(.black)
                    Spacer()
                    Button("Add") {
                        store.add(FoodEntry(
                            name: name, brand: "",
                            calories: Double(calories) ?? 0,
                            protein: Double(protein) ?? 0,
                            fat: Double(fat) ?? 0,
                            carbs: Double(carbs) ?? 0,
                            servingSize: servingSize, quantity: 1, timestamp: Date()
                        ), for: date)
                        dismiss(); onAdded()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(canSave ? .black : .gray)
                    .disabled(!canSave)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 12) {
                        manualField("Food Name *", text: $name)
                        manualField("Serving Size", text: $servingSize)
                        manualField("Calories *", text: $calories, keyboard: .decimalPad)
                        manualField("Protein (g)", text: $protein, keyboard: .decimalPad)
                        manualField("Fat (g)", text: $fat, keyboard: .decimalPad)
                        manualField("Carbs (g)", text: $carbs, keyboard: .decimalPad)
                    }
                    .padding()
                }
            }
        }
        .onAppear { name = prefillName }
    }

    @ViewBuilder
    private func manualField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.gray)
            TextField("", text: text)
                .keyboardType(keyboard).foregroundColor(.black)
                .padding(12).background(Color.white).cornerRadius(10)
        }
    }
}
