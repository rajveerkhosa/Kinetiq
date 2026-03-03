import SwiftUI

struct WorkoutSplitView: View {
    @State private var selectedSplit: WorkoutSplit = .upperLower
    @State private var restDaysPerWeek: Int = 2

    let workoutSplits: [WorkoutSplit] = [
        .upperLower,
        .fullBody,
        .broSplit,
        .arnold,
        .ppl,
        .pplArnold
    ]

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training Program")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)

                        Text("Choose your workout split and rest days")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Workout Split Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Workout Split")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(workoutSplits, id: \.self) { split in
                                WorkoutSplitCard(
                                    split: split,
                                    isSelected: selectedSplit == split,
                                    onSelect: {
                                        withAnimation {
                                            selectedSplit = split
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Rest Days Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rest Days Per Week")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { days in
                                RestDayCard(
                                    days: days,
                                    isSelected: restDaysPerWeek == days,
                                    onSelect: {
                                        withAnimation {
                                            restDaysPerWeek = days
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Save Button
                    Button(action: {
                        // Save selection
                    }) {
                        Text("Save Program")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct WorkoutSplitCard: View {
    let split: WorkoutSplit
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(split.name)
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(split.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text("\(split.daysPerWeek) days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .black : .gray)
            }
            .padding()
            .background(isSelected ? Color.black.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct RestDayCard: View {
    let days: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(days) Rest Day\(days > 1 ? "s" : "")")
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(restDayDescription(days))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<days, id: \.self) { _ in
                        Image(systemName: "bed.double.fill")
                            .font(.caption)
                            .foregroundColor(isSelected ? .black : .gray.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.black.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
        }
    }

    func restDayDescription(_ days: Int) -> String {
        switch days {
        case 1:
            return "Train 6 days a week - advanced"
        case 2:
            return "Train 5 days a week - recommended"
        case 3:
            return "Train 4 days a week - beginner friendly"
        default:
            return ""
        }
    }
}

enum WorkoutSplit: String, CaseIterable {
    case upperLower = "Upper/Lower"
    case fullBody = "Full Body"
    case broSplit = "Bro Split"
    case arnold = "Arnold Split"
    case ppl = "PPL"
    case pplArnold = "PPL Arnold"

    var name: String {
        return rawValue
    }

    var description: String {
        switch self {
        case .upperLower:
            return "Alternate between upper and lower body workouts"
        case .fullBody:
            return "Full body workout each session"
        case .broSplit:
            return "One muscle group per day (Chest, Back, Legs, Shoulders, Arms)"
        case .arnold:
            return "Chest/Back, Shoulders/Arms, Legs - twice a week"
        case .ppl:
            return "Push, Pull, Legs rotation"
        case .pplArnold:
            return "PPL with Arnold split variations"
        }
    }

    var daysPerWeek: Int {
        switch self {
        case .upperLower:
            return 4
        case .fullBody:
            return 3
        case .broSplit:
            return 5
        case .arnold:
            return 6
        case .ppl:
            return 6
        case .pplArnold:
            return 6
        }
    }
}

#Preview {
    WorkoutSplitView()
}
