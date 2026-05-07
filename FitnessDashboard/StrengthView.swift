import Charts
import SwiftUI

private let strengthBg = Color(red: 0.95, green: 0.95, blue: 0.97)
private let fallbackLifts = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]

struct DBPerformanceSet {
    let sessionDate: Date
    let setNumber: Int
    let actualReps: Int
    let actualWeightLbs: Double

    var e1rm: Double {
        guard actualReps > 0, actualReps <= 12, actualWeightLbs > 0 else { return 0 }
        return actualWeightLbs * (1 + Double(actualReps) / 30.0)
    }
}

struct StrengthView: View {
    @State private var dbSets: [DBPerformanceSet] = []
    @State private var isLoadingPerformance = false
    @ObservedObject private var workoutData = WorkoutDataStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var selectedLift = "Bench Press"
    @State private var show1RMCalculator = false
    @State private var calcWeight: String = ""
    @State private var calcReps: Int = 5

    private var trackedLifts: [String] {
        var seen = [String]()
        var added = Set<String>()
        for session in workoutData.recentWorkouts {
            for exercise in session.exercises {
                let name = exercise.name
                if !added.contains(name) {
                    seen.append(name)
                    added.insert(name)
                }
            }
        }
        return seen.isEmpty ? fallbackLifts : seen
    }

    private var e1rmValue: Double? { dbE1rm ?? workoutData.e1rm(for: selectedLift) }
    private var trend: [(date: Date, e1rm: Double)] { dbTrend.isEmpty ? workoutData.e1rmTrend(for: selectedLift) : dbTrend }
    private var weightData: [(date: Date, weight: Double, reps: Int)] {
        dbWeightHistory.isEmpty ? workoutData.weightHistory(for: selectedLift) : dbWeightHistory
    }

    private var dbE1rm: Double? {
        let estimates = dbSets
            .filter { $0.actualReps > 0 && $0.actualReps <= 12 && $0.actualWeightLbs > 0 }
            .map { $0.e1rm }
        return estimates.max()
    }

    private var dbTrend: [(date: Date, e1rm: Double)] {
        var byDate: [Date: Double] = [:]
        for set in dbSets {
            let day = Calendar.current.startOfDay(for: set.sessionDate)
            let est = set.e1rm
            if est > 0 {
                byDate[day] = max(byDate[day] ?? 0, est)
            }
        }
        return byDate.map { (date: $0.key, e1rm: $0.value) }.sorted { $0.date < $1.date }
    }

    private var dbWeightHistory: [(date: Date, weight: Double, reps: Int)] {
        dbSets
            .filter { $0.actualWeightLbs > 0 && $0.actualReps > 0 }
            .map { (date: $0.sessionDate, weight: $0.actualWeightLbs, reps: $0.actualReps) }
    }

    private func display(_ lbs: Double) -> Int {
        settings.weightUnit == .metric ? Int(lbs * 0.453592) : Int(lbs)
    }
    private var unitLabel: String { settings.weightUnit.rawValue }

    var body: some View {
        ZStack {
            strengthBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    liftSelector
                    heroCard
                    trendCard
                    weightProgressCard
                    recentSetsCard
                    mlCard
                    Spacer().frame(height: 20)
                }
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $show1RMCalculator) { oneRMCalculatorSheet }
        .onAppear {
            if !trackedLifts.contains(selectedLift), let first = trackedLifts.first {
                selectedLift = first
            }
        }
        .onChange(of: trackedLifts) { newLifts in
            if !newLifts.contains(selectedLift), let first = newLifts.first {
                selectedLift = first
            }
        }
        .task {
            fetchPerformance(for: selectedLift)
        }
        .onChange(of: selectedLift) { newLift in
            fetchPerformance(for: newLift)
        }
    }

    // MARK: - Fetch Performance

    private func fetchPerformance(for exerciseName: String) {
        let userId = UserDefaults.standard.integer(forKey: "user_id")
        guard userId > 0 else { return }

        let encoded = exerciseName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? exerciseName
        guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/performance/\(userId)/\(encoded)") else { return }

        isLoadingPerformance = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let records = json["performance"] as? [[String: Any]] {

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"

                    let parsed: [DBPerformanceSet] = records.compactMap { record in
                        guard let dateStr = record["session_date"] as? String,
                              let date = formatter.date(from: dateStr),
                              let reps = record["actual_reps"] as? Int,
                              let weight = record["actual_weight_lbs"] as? Double else { return nil }
                        return DBPerformanceSet(
                            sessionDate: date,
                            setNumber: record["set_number"] as? Int ?? 0,
                            actualReps: reps,
                            actualWeightLbs: weight
                        )
                    }

                    await MainActor.run {
                        dbSets = parsed.sorted { $0.sessionDate < $1.sessionDate }
                        isLoadingPerformance = false
                    }
                }
            } catch {
                print("Error fetching performance:", error)
                await MainActor.run { isLoadingPerformance = false }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strength")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.black)
                Text("Estimated 1 Rep Max")
                    .font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 28))
                .foregroundColor(.black.opacity(0.12))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Lift Selector

    private var liftSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(trackedLifts, id: \.self) { lift in
                    Button(action: { selectedLift = lift }) {
                        Text(lift)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(selectedLift == lift ? .white : .black)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(selectedLift == lift ? Color.black : Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 4) {
            if let val = e1rmValue {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(display(val))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text(unitLabel)
                        .font(.title2).foregroundColor(.gray)
                }
                Text("Estimated 1RM")
                    .font(.subheadline).foregroundColor(.gray)

                if let bestSet = bestSetForSelectedLift {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.caption2).foregroundColor(.blue)
                        Text("Based on \(display(bestSet.weight)) \(unitLabel) × \(bestSet.reps) reps")
                            .font(.caption).foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }

                Button(action: { show1RMCalculator = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "function").font(.caption2)
                        Text("1RM Calculator")
                    }
                    .font(.caption).foregroundColor(.blue)
                }
                .padding(.top, 8)

            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36)).foregroundColor(.black.opacity(0.15))
                    .padding(.bottom, 4)
                Text("No data yet")
                    .font(.headline).foregroundColor(.black)
                Text("Log a \(selectedLift) to get started")
                    .font(.subheadline).foregroundColor(.gray)

                Button(action: { show1RMCalculator = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "function").font(.caption2)
                        Text("1RM Calculator")
                    }
                    .font(.caption).foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    private var bestSetForSelectedLift: ExerciseSet? {
        workoutData.history(for: selectedLift)
            .filter { $0.reps > 0 && $0.reps <= 12 && $0.weight > 0 }
            .max { a, b in
                (a.weight * (1 + Double(a.reps) / 30.0)) < (b.weight * (1 + Double(b.reps) / 30.0))
            }
    }

    // MARK: - Trend Chart (E1RM)

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("E1RM Over Time")
                .font(.headline).foregroundColor(.black)

            if trend.count < 2 {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 28))
                            .foregroundColor(.black.opacity(0.15))
                        Text("Log more sets to see trend")
                            .font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                let maxVal = trend.map(\.e1rm).max() ?? 1
                let minVal = trend.map(\.e1rm).min() ?? 0
                let range = max(maxVal - minVal, 1)

                GeometryReader { geo in
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(trend.enumerated()), id: \.offset) { idx, point in
                            let normalized = (point.e1rm - minVal) / range
                            let barH = max(CGFloat(normalized) * (geo.size.height - 24) + 24, 24)
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(idx == trend.count - 1 ? Color.black : Color.blue.opacity(0.35))
                                    .frame(height: barH)
                                Text(shortDate(point.date))
                                    .font(.system(size: 8)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: geo.size.height)
                }
                .frame(height: 120)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }

    // MARK: - Weight Progress Chart

    private var weightProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weight Progress")
                .font(.headline).foregroundColor(.black)

            if weightData.count < 2 {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28))
                            .foregroundColor(.black.opacity(0.15))
                        Text("Log more sets to see weight history")
                            .font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                Chart {
                    ForEach(Array(weightData.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", display(point.weight))
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", display(point.weight))
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(point.reps)r")
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                        AxisGridLine()
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Sets

    private var recentSetsCard: some View {
        let sets = workoutData.history(for: selectedLift)
            .filter { $0.weight > 0 && $0.reps > 0 }
            .suffix(6)
            .reversed()

        return VStack(alignment: .leading, spacing: 0) {
            Text("Recent Sets")
                .font(.headline).foregroundColor(.black)
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

            if sets.isEmpty {
                Text("No sets logged yet")
                    .font(.subheadline).foregroundColor(.gray)
                    .padding(.horizontal, 18).padding(.bottom, 18)
            } else {
                ForEach(Array(sets.enumerated()), id: \.offset) { idx, set in
                    HStack {
                        Text("Set \(sets.count - idx)")
                            .font(.subheadline).foregroundColor(.gray).frame(width: 46, alignment: .leading)
                        Text("\(display(set.weight)) \(unitLabel) × \(set.reps)")
                            .font(.subheadline).fontWeight(.medium).foregroundColor(.black)
                        Spacer()
                        let est = set.reps <= 12 ? Int(set.weight * (1 + Double(set.reps) / 30.0)) : nil
                        if let est {
                            Text("~\(display(Double(est)))")
                                .font(.caption).foregroundColor(.blue)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    if idx < sets.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - ML Card

    private var mlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22)).foregroundColor(.black)
                Text("AI Prediction")
                    .font(.headline).foregroundColor(.black)
                Spacer()
            }

            if let val = e1rmValue {
                mlMetricRow(icon: "dumbbell.fill", label: "Current E1RM",
                            value: "\(display(val)) \(unitLabel)")
            }

            if trend.count >= 2 {
                let projected = projectedE1RM(inWeeks: 4)
                mlMetricRow(icon: "chart.line.uptrend.xyaxis",
                            label: "Projected E1RM (4 wks)",
                            value: "\(display(projected)) \(unitLabel)")
            }

            if let suggestion = workoutData.lastSuggestions[selectedLift] {
                if let plateau = suggestion.plateauInfo {
                    let isPlateau = plateau.isPlateau
                    let plateauText = isPlateau
                        ? "Plateau (\(plateau.weeksAtSameWeight) wks)"
                        : "Progressing"
                    let icon = isPlateau ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    mlMetricRow(icon: icon, label: "Plateau Status",
                                value: plateauText,
                                valueColor: isPlateau ? .orange : .green)
                }

                if let reliability = suggestion.rpeReliability, reliability.nObservations >= 3 {
                    mlMetricRow(icon: "waveform.path.ecg", label: "RPE Reliability",
                                value: "\(Int(reliability.score * 100))%")
                }

                if let plateau = suggestion.plateauInfo, plateau.isPlateau {
                    Text(plateau.explanation)
                        .font(.caption).foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(["Trend Analysis", "RPE Tracking", "PR Forecasting"], id: \.self) { tag in
                        Text(tag).font(.caption).foregroundColor(.black)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.06)).cornerRadius(8)
                    }
                }
                Text("Log a set with RPE to unlock AI predictions.")
                    .font(.caption).foregroundColor(.gray)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    private func mlMetricRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .black
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption).foregroundColor(.gray).frame(width: 16)
            Text(label)
                .font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.semibold).foregroundColor(valueColor)
        }
    }

    private func projectedE1RM(inWeeks weeks: Int) -> Double {
        guard trend.count >= 2 else { return e1rmValue ?? 0 }
        let n = Double(trend.count)
        let xMean = (n - 1) / 2.0
        let yMean = trend.map(\.e1rm).reduce(0, +) / n
        let numerator = trend.enumerated().reduce(0.0) { acc, pair in
            acc + (Double(pair.offset) - xMean) * (pair.element.e1rm - yMean)
        }
        let denominator = trend.indices.reduce(0.0) { acc, i in
            acc + (Double(i) - xMean) * (Double(i) - xMean)
        }
        let slope = denominator != 0 ? numerator / denominator : 0
        let stepsForward = Double(weeks) * 2.0
        return max(0, (trend.last?.e1rm ?? 0) + slope * stepsForward)
    }

    // MARK: - 1RM Calculator Sheet

    private var oneRMCalculatorSheet: some View {
        NavigationStack {
            Form {
                Section("Input") {
                    HStack {
                        Text("Weight (\(unitLabel))")
                        Spacer()
                        TextField("0", text: $calcWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Stepper("Reps: \(calcReps)", value: $calcReps, in: 1...20)
                }

                if let w = Double(calcWeight), w > 0, calcReps >= 1 {
                    let wLbs = settings.weightUnit == .metric ? w / 0.453592 : w
                    let epley = wLbs * (1.0 + Double(calcReps) / 30.0)
                    let brzycki = calcReps < 37 ? wLbs * (36.0 / (37.0 - Double(calcReps))) : epley
                    let lombardi = wLbs * pow(Double(calcReps), 0.1)

                    Section("Estimated 1RM") {
                        FormulaRow(name: "Epley",    value: display(epley),    unit: unitLabel, isDefault: true)
                        FormulaRow(name: "Brzycki",  value: display(brzycki),  unit: unitLabel, isDefault: false)
                        FormulaRow(name: "Lombardi", value: display(lombardi), unit: unitLabel, isDefault: false)
                    }

                    Section("Average") {
                        let avg = (epley + brzycki + lombardi) / 3.0
                        HStack {
                            Text("Mean estimate")
                            Spacer()
                            Text("\(display(avg)) \(unitLabel)")
                                .fontWeight(.semibold).foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("1RM Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { show1RMCalculator = false }
                }
            }
        }
    }
}

// MARK: - Formula Row

fileprivate struct FormulaRow: View {
    let name: String
    let value: Int
    let unit: String
    let isDefault: Bool

    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(isDefault ? .primary : .secondary)
            if isDefault {
                Text("(default)")
                    .font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            Text("\(value) \(unit)")
                .fontWeight(isDefault ? .semibold : .regular)
                .foregroundColor(isDefault ? .primary : .secondary)
        }
    }
}

#Preview {
    StrengthView()
}