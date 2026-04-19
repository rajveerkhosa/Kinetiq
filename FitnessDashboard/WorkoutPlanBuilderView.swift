import SwiftUI

struct WorkoutPlanBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var planName = ""
    @State private var selectedExercises: [WorkoutExercise] = []
    @State private var showExercisePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Plan Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan Name")
                            .font(.headline)
                            .foregroundColor(.black)

                        TextField("e.g., Push Day, Leg Day", text: $planName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding()

                    // Exercise List
                    if selectedExercises.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))

                            Text("No exercises added yet")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("Tap the button below to add exercises")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))

                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(selectedExercises.indices, id: \.self) { index in
                                    VStack(spacing: 12) {
                                        HStack(spacing: 16) {
                                            // Icon
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.1))
                                                    .frame(width: 44, height: 44)

                                                Image(systemName: "dumbbell.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(selectedExercises[index].name)
                                                    .font(.headline)
                                                    .foregroundColor(.black)

                                                Text("\(selectedExercises[index].sets.count) sets")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }

                                            Spacer()

                                            // Remove button
                                            Button(action: {
                                                selectedExercises.remove(at: index)
                                            }) {
                                                Image(systemName: "trash.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }

                                        // Sets control
                                        HStack {
                                            Text("Sets:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)

                                            Spacer()

                                            HStack(spacing: 12) {
                                                Button(action: {
                                                    if selectedExercises[index].sets.count > 1 {
                                                        selectedExercises[index].sets.removeLast()
                                                    }
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundColor(selectedExercises[index].sets.count > 1 ? .black : .gray.opacity(0.3))
                                                }
                                                .disabled(selectedExercises[index].sets.count <= 1)

                                                Text("\(selectedExercises[index].sets.count)")
                                                    .font(.headline)
                                                    .foregroundColor(.black)
                                                    .frame(minWidth: 30)

                                                Button(action: {
                                                    if selectedExercises[index].sets.count < 10 {
                                                        selectedExercises[index].sets.append(
                                                            ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
                                                        )
                                                    }
                                                }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundColor(selectedExercises[index].sets.count < 10 ? .black : .gray.opacity(0.3))
                                                }
                                                .disabled(selectedExercises[index].sets.count >= 10)
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                            }
                            .padding()
                        }
                    }

                    // Add Exercise Button
                    Button(action: {
                        showExercisePicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkoutPlan()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                    .disabled(planName.isEmpty || selectedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(selectedExercises: $selectedExercises)
            }
        }
    }


	func saveWorkoutPlan() {
    let userId = UserDefaults.standard.integer(forKey: "user_id")
    guard userId > 0 else {
        print("No user_id found")
        return
    }

    Task {
        do {
            // Step 1 - Create the plan
            guard let planUrl = URL(string: "https://kinetiq-dzfm.onrender.com/plans") else { return }
            var planRequest = URLRequest(url: planUrl)
            planRequest.httpMethod = "POST"
            planRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let planBody: [String: Any] = [
                "user_id": userId,
                "plan_name": planName
            ]
            planRequest.httpBody = try JSONSerialization.data(withJSONObject: planBody)

            let (planData, _) = try await URLSession.shared.data(for: planRequest)
            guard let planJson = try JSONSerialization.jsonObject(with: planData) as? [String: Any],
                  let planId = planJson["plan_id"] as? Int else {
                print("Failed to get plan_id from response")
                return
            }

            // Save active plan id locally
            UserDefaults.standard.set(planId, forKey: "active_plan_id")

            // Step 2 - Add each exercise to the plan
            for exercise in selectedExercises {
                guard let exUrl = URL(string: "https://kinetiq-dzfm.onrender.com/plans/exercises") else { continue }
                var exRequest = URLRequest(url: exUrl)
                exRequest.httpMethod = "POST"
                exRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let exBody: [String: Any] = [
                    "plan_id": planId,
                    "exercise_name": exercise.name,
                    "target_sets": exercise.sets.count,
                    "target_reps": 10
                ]
                exRequest.httpBody = try JSONSerialization.data(withJSONObject: exBody)
                _ = try await URLSession.shared.data(for: exRequest)
            }

            print("Plan saved successfully with plan_id: \(planId)")

            await MainActor.run {
                dismiss()
            }

        } catch {
            print("Error saving plan:", error)
        }
    }
}


#Preview {
    WorkoutPlanBuilderView()
}
