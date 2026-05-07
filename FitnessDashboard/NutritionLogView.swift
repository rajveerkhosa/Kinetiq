import SwiftUI

private let appBg = Color(red: 0.95, green: 0.95, blue: 0.97)

struct NutritionLogView: View {
    @ObservedObject private var store = NutritionStore.shared
    @ObservedObject private var profile = UserProfile.shared
    @State private var selectedDate = Date()
    @State private var showSearch = false

    private var goals: DailyGoals { store.dailyGoals(for: profile) }
    private var totals: (calories: Double, protein: Double, fat: Double, carbs: Double) {
        store.totals(for: selectedDate)
    }
    private var entries: [FoodEntry] { store.entries(for: selectedDate) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var body: some View {
        ZStack(alignment: .bottom) {
            appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCard
                        if entries.isEmpty {
                            emptyState
                        } else {
                            logList
                        }
                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 12)
                }
            }

            bottomBar
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(date: selectedDate)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)! }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(isToday ? "Today" : dateTitle)
                    .font(.headline)
                    .foregroundColor(.black)
                Text(dateSubtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: {
                if !isToday {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isToday ? .gray.opacity(0.3) : .black)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(appBg)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 8)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(totals.calories) / CGFloat(max(goals.calories, 1)), 1.0))
                        .stroke(calorieColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: totals.calories)
                    VStack(spacing: 1) {
                        Text("\(Int(totals.calories))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        Text("/ \(goals.calories)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                VStack(spacing: 10) {
                    macroBar(label: "P", current: totals.protein, goal: Double(goals.protein), color: Color(red: 0.9, green: 0.3, blue: 0.3))
                    macroBar(label: "F", current: totals.fat,     goal: Double(goals.fat),     color: Color(red: 0.95, green: 0.7, blue: 0.1))
                    macroBar(label: "C", current: totals.carbs,   goal: Double(goals.carbs),   color: Color(red: 0.2, green: 0.7, blue: 0.4))
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func macroBar(label: String, current: Double, goal: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(color)
                .frame(width: 12)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.07)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: min(CGFloat(current / max(goal, 1)) * geo.size.width, geo.size.width), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: current)
                }
            }
            .frame(height: 6)
            Text("\(Int(current))g")
                .font(.caption).foregroundColor(.black).frame(width: 38, alignment: .trailing)
            Text("/ \(Int(goal))g")
                .font(.caption).foregroundColor(.gray).frame(width: 42, alignment: .leading)
        }
    }

    // MARK: - Log List

    private var logList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Log")
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.gray)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    FoodLogRow(entry: entry, date: selectedDate)
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.black.opacity(0.12))
            Text("Nothing logged yet")
                .font(.subheadline).foregroundColor(.gray)
            Text("Tap the search bar below to add food")
                .font(.caption).foregroundColor(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Button(action: { showSearch = true }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                Text("Search for a food").foregroundColor(.gray)
                Spacer()
                Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.black)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Helpers

    private var calorieColor: Color {
        let ratio = totals.calories / Double(max(goals.calories, 1))
        if ratio >= 1.0 { return .red }
        if ratio >= 0.85 { return .orange }
        return .black
    }

    private var dateTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: selectedDate)
    }
    private var dateSubtitle: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: selectedDate)
    }
}

// MARK: - Food Log Row

struct FoodLogRow: View {
    let entry: FoodEntry
    let date: Date
    @ObservedObject private var store = NutritionStore.shared
    @State private var showDelete = false

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(appBg).frame(width: 44, height: 44)
                Image(systemName: "fork.knife").foregroundColor(.gray).font(.system(size: 15))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.black).lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(Int(entry.calories * entry.quantity)) kcal").foregroundColor(.orange)
                    Text("·").foregroundColor(.gray)
                    Text("\(Int(entry.protein * entry.quantity))P  \(Int(entry.fat * entry.quantity))F  \(Int(entry.carbs * entry.quantity))C").foregroundColor(.gray)
                }
                .font(.caption)
                Text(timeString).font(.caption2).foregroundColor(.gray.opacity(0.6))
            }
            Spacer()
            Button(action: { showDelete = true }) {
                Image(systemName: "trash").font(.footnote).foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .confirmationDialog("Remove \(entry.name)?", isPresented: $showDelete) {
            Button("Remove", role: .destructive) { store.delete(entry, for: date) }
        }
    }
}

#Preview {
    NutritionLogView()
}
