import SwiftUI

private let lightBg = Color(red: 0.95, green: 0.95, blue: 0.97)

struct OpenFoodResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let servingSize: String
}

class FoodSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [OpenFoodResult] = []
    @Published var isLoading = false

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        isLoading = true

        searchTask = Task {
            do {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                let urlStr = "https://world.openfoodfacts.net/api/v2/search?search_terms=\(encoded)&page_size=25&fields=product_name,brands,nutriments,serving_size&lc=en&cc=us"
                guard let url = URL(string: urlStr) else { return }

                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let products = json?["products"] as? [[String: Any]] ?? []

                let parsed: [OpenFoodResult] = products.compactMap { p in
                    guard let name = p["product_name"] as? String, !name.isEmpty else { return nil }
                    let n = p["nutriments"] as? [String: Any] ?? [:]
                    let cal  = n["energy-kcal_100g"] as? Double ?? 0
                    let prot = n["proteins_100g"]    as? Double ?? 0
                    let fat  = n["fat_100g"]          as? Double ?? 0
                    let carb = n["carbohydrates_100g"] as? Double ?? 0
                    let brand   = p["brands"] as? String ?? ""
                    let serving = p["serving_size"] as? String ?? "100g"
                    return OpenFoodResult(name: name, brand: brand, calories: cal, protein: prot, fat: fat, carbs: carb, servingSize: serving)
                }

                await MainActor.run {
                    self.results = parsed
                    self.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.isLoading = false }
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
                    TextField("Search for a food...", text: $vm.query)
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .onSubmit { vm.search() }
                    if !vm.query.isEmpty {
                        Button(action: { vm.query = ""; vm.results = [] }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(.black)
                    Spacer()
                } else if vm.results.isEmpty && !vm.query.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("No results found").foregroundColor(.gray)
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
                                Divider().padding(.leading, 72)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
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
    let result: OpenFoodResult
    let date: Date
    let onAdded: () -> Void
    @ObservedObject private var store = NutritionStore.shared
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(lightBg).frame(width: 44, height: 44)
                    Image(systemName: "fork.knife").foregroundColor(.gray).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.name)
                        .font(.subheadline).fontWeight(.medium).foregroundColor(.black).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(Int(result.calories)) kcal").foregroundColor(.orange)
                        Text("·").foregroundColor(.gray)
                        Text("\(Int(result.protein))P  \(Int(result.fat))F  \(Int(result.carbs))C").foregroundColor(.gray)
                    }
                    .font(.caption)
                    if !result.brand.isEmpty {
                        Text(result.brand).font(.caption2).foregroundColor(.gray.opacity(0.7)).lineLimit(1)
                    }
                }
                Spacer()
                Button(action: {
                    store.add(FoodEntry(
                        name: result.name, brand: result.brand,
                        calories: result.calories, protein: result.protein,
                        fat: result.fat, carbs: result.carbs,
                        servingSize: result.servingSize, quantity: 1, timestamp: Date()
                    ), for: date)
                    onAdded()
                }) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showDetail) {
            FoodDetailView(result: result, date: date, onAdded: onAdded)
        }
    }
}

struct FoodDetailView: View {
    let result: OpenFoodResult
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

                Text(result.name)
                    .font(.title3).fontWeight(.bold).foregroundColor(.black)
                    .multilineTextAlignment(.center).padding(.horizontal)

                if !result.brand.isEmpty {
                    Text(result.brand).font(.subheadline).foregroundColor(.gray)
                }

                HStack(spacing: 16) {
                    macroPill(label: "CAL", value: Int(scaled.cal), color: .orange)
                    macroPill(label: "P",   value: Int(scaled.p),   color: Color(red: 0.9, green: 0.3, blue: 0.3))
                    macroPill(label: "F",   value: Int(scaled.f),   color: Color(red: 0.85, green: 0.65, blue: 0.1))
                    macroPill(label: "C",   value: Int(scaled.c),   color: Color(red: 0.2, green: 0.7, blue: 0.4))
                }

                VStack(spacing: 8) {
                    Text("Servings (per 100g)").font(.caption).foregroundColor(.gray)
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
                        name: result.name, brand: result.brand,
                        calories: result.calories, protein: result.protein,
                        fat: result.fat, carbs: result.carbs,
                        servingSize: result.servingSize, quantity: quantity, timestamp: Date()
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
    @State private var brand = ""
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
                            name: name, brand: brand,
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
                        manualField("Brand (optional)", text: $brand)
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
