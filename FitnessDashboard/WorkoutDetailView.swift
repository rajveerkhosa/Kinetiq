import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white)

                ScrollView {
                    VStack(spacing: 20) {
                        // Workout Summary
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(workout.type)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)

                                    Text(formatDate(workout.date))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }

                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(workout.duration)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                    Text("minutes")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Divider().frame(height: 40)

                                VStack(spacing: 4) {
                                    Text("\(workout.totalSets)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                    Text("sets")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Divider().frame(height: 40)

                                VStack(spacing: 4) {
                                    Text(String(format: "%.1fk", workout.totalVolume / 1000))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                    Text("lbs lifted")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Exercises
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Exercises")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal)

                            ForEach(workout.exercises) { exercise in
                                ExerciseDetailCard(exercise: exercise)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }
}

struct ExerciseDetailCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(exercise.muscleGroup)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("\(exercise.sets.count) sets")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Divider()

            // Sets table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SET")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .leading)

                    Spacer()

                    Text("WEIGHT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(width: 80, alignment: .center)

                    Spacer()

                    Text("REPS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .center)

                    Spacer()

                    Text("VOLUME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Rows
                ForEach(exercise.sets) { set in
                    HStack {
                        Text("\(set.setNumber)")
                            .font(.subheadline)
                            .foregroundColor(.black)
                            .frame(width: 40, alignment: .leading)

                        Spacer()

                        HStack(spacing: 2) {
                            Text(String(format: "%.0f", set.weight))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("lbs")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, alignment: .center)

                        Spacer()

                        Text("\(set.reps)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 60, alignment: .center)

                        Spacer()

                        Text(String(format: "%.0f", set.weight * Double(set.reps)))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)

                    if set.id != exercise.sets.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    WorkoutDetailView(workout: WorkoutDataStore.shared.recentWorkouts[0])
}
