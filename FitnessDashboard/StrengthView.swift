import SwiftUI

private let strengthBg = Color(red: 0.95, green: 0.95, blue: 0.97)

private let trackedLifts = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]

struct StrengthView: View {
    @ObservedObject private var workoutData = WorkoutDataStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var selectedLift = "Bench Press"

    private var e1rmValue: Double? { workoutData.e1rm(for: selectedLift) }
    private var trend: [(date: Date, e1rm: Double)] { workoutData.e1rmTrend(for: selectedLift) }

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
                    recentSetsCard
                    mlCard
                    Spacer().frame(height: 20)
                }
                .padding(.top, 12)
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

                // Best set used
                if let bestSet = bestSetForSelectedLift {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.caption2).foregroundColor(.blue)
                        Text("Based on \(display(bestSet.weight)) \(unitLabel) × \(bestSet.reps) reps")
                            .font(.caption).foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36)).foregroundColor(.black.opacity(0.15))
                    .padding(.bottom, 4)
                Text("No data yet")
                    .font(.headline).foregroundColor(.black)
                Text("Log a \(selectedLift) to get started")
                    .font(.subheadline).foregroundColor(.gray)
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

    // MARK: - Trend Chart

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

    // MARK: - ML Card (Coming Soon)

    private var mlCard: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22)).foregroundColor(.black)
                    Text("AI Prediction")
                        .font(.headline).foregroundColor(.black)
                    Spacer()
                }
                Text("Your friend's ML algorithm will predict your next PR based on training history, RPE trends, and recovery patterns.")
                    .font(.subheadline).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ForEach(["Trend Analysis", "RPE Tracking", "PR Forecasting"], id: \.self) { tag in
                        Text(tag).font(.caption).foregroundColor(.black)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.06)).cornerRadius(8)
                    }
                }
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            .opacity(0.5)

            // Coming Soon overlay
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 18)).foregroundColor(.white)
                Text("Coming Soon").font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    StrengthView()
}
