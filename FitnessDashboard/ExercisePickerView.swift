import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedExercises: [WorkoutExercise]
    @State private var selectedMuscleGroup: MuscleGroup? = nil
    @State private var searchText = ""

    @StateObject private var library = ExerciseLibrary.shared

    var filteredExercises: [ExerciseLibraryItem] {
        let exercises = selectedMuscleGroup != nil
            ? library.exercises.filter { $0.muscleGroup == selectedMuscleGroup! }
            : library.exercises

        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search exercises", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding()

                    // Muscle Group Filter
                    if selectedMuscleGroup == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(MuscleGroup.allCases) { muscleGroup in
                                    MuscleGroupCard(muscleGroup: muscleGroup) {
                                        withAnimation {
                                            selectedMuscleGroup = muscleGroup
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    } else {
                        // Back to all muscle groups
                        HStack {
                            Button(action: {
                                withAnimation {
                                    selectedMuscleGroup = nil
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("All Muscle Groups")
                                }
                                .foregroundColor(.black)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            }

                            Spacer()

                            Text(selectedMuscleGroup!.rawValue)
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }

                    // Exercise List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredExercises) { exercise in
                                ExerciseSelectionCard(exercise: exercise) {
                                    addExercise(exercise)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .task {
            await library.fetchExercises()
        }
    }

    func addExercise(_ exercise: ExerciseLibraryItem) {
        let newExercise = WorkoutExercise(
            name: exercise.name,
            sets: [ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)],
            lastPerformance: nil
        )
        selectedExercises.append(newExercise)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        dismiss()
    }
}

struct MuscleGroupCard: View {
    let muscleGroup: MuscleGroup
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: muscleGroup.icon)
                        .font(.title2)
                        .foregroundColor(.black)
                }

                Text(muscleGroup.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct ExerciseSelectionCard: View {
    let exercise: ExerciseLibraryItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: exercise.muscleGroup.icon)
                        .font(.title3)
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.black)

                    HStack {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text("•")
                            .foregroundColor(.gray)
                            .font(.caption)

                        Text(exercise.equipment)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    ExercisePickerView(selectedExercises: .constant([]))
}
