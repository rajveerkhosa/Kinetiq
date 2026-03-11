import SwiftUI
import AVFoundation

struct ActiveWorkoutView: View {
    @Binding var isPresented: Bool
    let workoutType: String

    @State private var currentExerciseIndex = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var exercises: [WorkoutExercise] = []
    @State private var showOverview = false
    @State private var completedExercises: Set<Int> = []
    @State private var isResting = false
    @State private var isPaused = false
    @State private var restTimeRemaining: TimeInterval = 120
    @State private var restTimer: Timer?
    @State private var showConfetti = false
    @State private var workoutCompleted = false
    @State private var showExercisePicker = false
    @State private var showCompletionScreen = false

    // ML suggestion state: key = "exerciseIndex_setIndex"
    @State private var suggestions: [String: KinetiqService.SuggestionResponse] = [:]
    @State private var isLoadingSuggestion: [String: Bool] = [:]

    @ObservedObject var settings = UserSettings.shared

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Timer and Rest Timer
                        HStack(spacing: 16) {
                            // Workout Timer
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formattedTime)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            // Rest Timer
                            if isResting {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(formattedRestTime)
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }

                        Spacer()

                        Button(action: {
                            showOverview = true
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Text(workoutType)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Exercise \(currentExerciseIndex + 1) of \(exercises.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 20)
                .background(Color.black)

                // Exercise Content
                if !exercises.isEmpty {
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 24) {
                            // Current Exercise
                            VStack(spacing: 16) {
                                Text(exercises[currentExerciseIndex].name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)

                                // Previous Performance
                                if let lastPerformance = exercises[currentExerciseIndex].lastPerformance {
                                    VStack(spacing: 4) {
                                        Text("Last Time")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                        Text(lastPerformance)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 20)

                            // Sets
                            VStack(spacing: 16) {
                                ForEach(exercises[currentExerciseIndex].sets.indices, id: \.self) { setIndex in
                                    VStack(spacing: 8) {
                                        SetRow(
                                            setNumber: setIndex + 1,
                                            set: $exercises[currentExerciseIndex].sets[setIndex]
                                        )
                                        .onChange(of: exercises[currentExerciseIndex].sets[setIndex].rpe) { newRpe in
                                            guard !newRpe.isEmpty else { return }
                                            fetchSuggestion(exerciseIndex: currentExerciseIndex, setIndex: setIndex)
                                        }

                                        // ML Suggestion card
                                        let sugKey = "\(currentExerciseIndex)_\(setIndex)"
                                        if isLoadingSuggestion[sugKey] == true {
                                            HStack {
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(0.8)
                                                Text("Getting next set recommendation…")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            .padding(.horizontal)
                                        } else if let suggestion = suggestions[sugKey] {
                                            SuggestionCard(suggestion: suggestion)
                                        }

                                        // Rest Button only for the latest completed set
                                        if !exercises[currentExerciseIndex].sets[setIndex].weight.isEmpty &&
                                           !exercises[currentExerciseIndex].sets[setIndex].reps.isEmpty &&
                                           setIndex == lastCompletedSetIndex {

                                            if isResting {
                                                VStack(spacing: 12) {
                                                    // Main rest timer display
                                                    VStack(spacing: 8) {
                                                        Text("Rest Timer")
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.white.opacity(0.6))

                                                        Text(formattedRestTime)
                                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                                            .monospacedDigit()
                                                            .foregroundColor(.white)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 20)
                                                    .background(Color.white.opacity(0.1))
                                                    .cornerRadius(16)

                                                    // Pause/Resume and End buttons
                                                    HStack(spacing: 12) {
                                                        Button(action: {
                                                            togglePauseRest()
                                                        }) {
                                                            HStack(spacing: 6) {
                                                                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                                                    .font(.system(size: 14))
                                                                Text(isPaused ? "Resume" : "Pause")
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                            }
                                                            .foregroundColor(.white)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .background(Color.white.opacity(0.15))
                                                            .cornerRadius(12)
                                                        }

                                                        Button(action: {
                                                            endRest()
                                                        }) {
                                                            HStack(spacing: 6) {
                                                                Image(systemName: "xmark")
                                                                    .font(.system(size: 14))
                                                                Text("Skip")
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                            }
                                                            .foregroundColor(.white)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .background(Color.white.opacity(0.15))
                                                            .cornerRadius(12)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal)
                                            } else {
                                                Button(action: {
                                                    startRest()
                                                }) {
                                                    HStack {
                                                        Image(systemName: "clock.fill")
                                                        Text("Start Rest")
                                                    }
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.black)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color.white)
                                                    .cornerRadius(10)
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }

                                // Add Set Button
                                Button(action: {
                                    exercises[currentExerciseIndex].sets.append(
                                        ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
                                    )
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Set")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)

                            }

                            // Exercise Management Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    removeCurrentExercise()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 14))
                                        Text("Remove")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    showExercisePicker = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 14))
                                        Text("Add Exercise")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // Navigation Buttons
                            HStack(spacing: 16) {
                                if currentExerciseIndex > 0 {
                                    Button(action: {
                                        stopRest()
                                        withAnimation {
                                            currentExerciseIndex -= 1
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "chevron.left")
                                            Text("Previous")
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(12)
                                    }
                                }

                                if currentExerciseIndex < exercises.count - 1 {
                                    Button(action: {
                                        stopRest()
                                        withAnimation {
                                            completedExercises.insert(currentExerciseIndex)
                                            currentExerciseIndex += 1
                                        }
                                    }) {
                                        HStack {
                                            Text("Next Exercise")
                                            Image(systemName: "chevron.right")
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(12)
                                    }
                                } else {
                                    Button(action: {
                                        completeWorkout()
                                    }) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Finish Workout")
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }

            // Confetti Animation
            if showConfetti {
                ConfettiView()
            }

            // Workout Completion Screen
            if showCompletionScreen {
                WorkoutCompletionView(
                    workoutType: workoutType,
                    duration: elapsedTime,
                    exercises: exercises,
                    onDismiss: {
                        showCompletionScreen = false
                        isPresented = false
                    }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showOverview) {
            WorkoutOverviewView(
                isPresented: $showOverview,
                showActiveWorkout: .constant(false),
                workoutType: workoutType,
                exercises: exercises,
                completedExercises: completedExercises,
                currentExercise: currentExerciseIndex
            )
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(selectedExercises: $exercises)
        }
        .onAppear {
            loadWorkoutExercises()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
        }
    }

    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedRestTime: String {
        let minutes = Int(restTimeRemaining) / 60
        let seconds = Int(restTimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var lastCompletedSetIndex: Int? {
        guard !exercises.isEmpty else { return nil }

        // Find the last set with both weight and reps filled
        for (index, set) in exercises[currentExerciseIndex].sets.enumerated().reversed() {
            if !set.weight.isEmpty && !set.reps.isEmpty {
                return index
            }
        }
        return nil
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    func startRest() {
        isResting = true
        isPaused = false
        restTimeRemaining = TimeInterval(settings.restTimerDuration)

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !isPaused && restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else if restTimeRemaining <= 0 {
                // Rest complete
                timer.invalidate()
                isResting = false
                isPaused = false

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    func togglePauseRest() {
        isPaused.toggle()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func endRest() {
        restTimer?.invalidate()
        isResting = false
        isPaused = false
        restTimeRemaining = TimeInterval(settings.restTimerDuration)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func stopRest() {
        restTimer?.invalidate()
        isResting = false
        isPaused = false
        restTimeRemaining = TimeInterval(settings.restTimerDuration)
    }

    func completeWorkout() {
        completedExercises.insert(currentExerciseIndex)
        workoutCompleted = true
        showConfetti = true

        // Save workout data
        saveWorkoutSession()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show confetti for 2 seconds, then show completion screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showConfetti = false
                showCompletionScreen = true
            }
        }
    }

    func saveWorkoutSession() {
        // Convert current workout exercises to Exercise objects
        var completedExercises: [Exercise] = []

        for workoutExercise in exercises {
            // Filter out sets that have both weight and reps filled
            let validSets = workoutExercise.sets.enumerated().compactMap { (index, set) -> ExerciseSet? in
                guard !set.weight.isEmpty, !set.reps.isEmpty,
                      let weightValue = Double(set.weight),
                      let repsValue = Int(set.reps) else {
                    return nil
                }

                return ExerciseSet(
                    weight: weightValue,
                    reps: repsValue,
                    setNumber: index + 1,
                    rpe: Double(set.rpe)   // nil if blank — fine for pre-RPE history
                )
            }

            // Only include exercises that have at least one valid set
            if !validSets.isEmpty {
                let exercise = Exercise(
                    name: workoutExercise.name,
                    sets: validSets,
                    muscleGroup: determineMuscleGroup(for: workoutExercise.name)
                )
                completedExercises.append(exercise)
            }
        }

        // Only save if there are completed exercises
        guard !completedExercises.isEmpty else { return }

        // Calculate duration in minutes
        let durationMinutes = Int(elapsedTime / 60)

        // Create workout session
        let session = WorkoutSession(
            date: Date(),
            type: workoutType,
            exercises: completedExercises,
            duration: durationMinutes
        )

        // Save to data store
        WorkoutDataStore.shared.saveWorkout(session)
    }

    func determineMuscleGroup(for exerciseName: String) -> String {
        // Simple matching based on exercise names
        let lowerName = exerciseName.lowercased()

        if lowerName.contains("bench") || lowerName.contains("chest") || lowerName.contains("fly") || lowerName.contains("flye") {
            return "Chest"
        } else if lowerName.contains("row") || lowerName.contains("pull") || lowerName.contains("lat") {
            return "Back"
        } else if lowerName.contains("squat") || lowerName.contains("leg press") || lowerName.contains("lunge") {
            return "Legs"
        } else if lowerName.contains("curl") && lowerName.contains("bicep") || lowerName.contains("bicep") {
            return "Biceps"
        } else if lowerName.contains("tricep") || lowerName.contains("pushdown") || lowerName.contains("skull") {
            return "Triceps"
        } else if lowerName.contains("shoulder") || lowerName.contains("press") && !lowerName.contains("bench") {
            return "Shoulders"
        } else if lowerName.contains("deadlift") || lowerName.contains("romanian") {
            return "Hamstrings"
        } else if lowerName.contains("calf") {
            return "Calves"
        } else if lowerName.contains("ab") || lowerName.contains("crunch") || lowerName.contains("plank") {
            return "Abs"
        }

        return "Other"
    }

    func loadWorkoutExercises() {
        let store = WorkoutDataStore.shared
        let unitStr = settings.weightUnit.rawValue

        func makeExercise(_ name: String, setCount: Int) -> WorkoutExercise {
            let lastPerf = store.lastPerformanceString(for: name, unit: unitStr)
            let sets = (0..<setCount).map { _ in
                ExerciseSetInput(weight: "", reps: "", rpe: "", completed: false)
            }
            return WorkoutExercise(name: name, sets: sets, lastPerformance: lastPerf)
        }

        if workoutType.contains("Upper") {
            exercises = [
                makeExercise("Bench Press", setCount: 3),
                makeExercise("Barbell Row", setCount: 3),
                makeExercise("Overhead Press", setCount: 3),
                makeExercise("Dumbbell Curl", setCount: 2),
                makeExercise("Tricep Pushdown", setCount: 2)
            ]
        } else {
            exercises = [
                makeExercise("Squat", setCount: 3),
                makeExercise("Romanian Deadlift", setCount: 3),
                makeExercise("Leg Press", setCount: 2)
            ]
        }
    }

    // MARK: - ML Suggestion

    func fetchSuggestion(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }

        let set = exercises[exerciseIndex].sets[setIndex]
        guard let weight = Double(set.weight),
              let reps = Int(set.reps),
              let rpe = Double(set.rpe),
              rpe >= 1, rpe <= 10 else { return }

        let exerciseName = exercises[exerciseIndex].name
        let key = "\(exerciseIndex)_\(setIndex)"

        isLoadingSuggestion[key] = true

        let lastExerciseSet = ExerciseSet(
            weight: weight,
            reps: reps,
            setNumber: setIndex + 1,
            rpe: rpe
        )
        let history = WorkoutDataStore.shared.history(for: exerciseName)

        Task {
            let response = try? await KinetiqService.shared.suggest(
                exerciseName: exerciseName,
                lastSet: lastExerciseSet,
                history: history
            )
            await MainActor.run {
                suggestions[key] = response
                isLoadingSuggestion[key] = false
            }
        }
    }

    func removeCurrentExercise() {
        guard exercises.count > 1 else { return }

        stopRest()
        exercises.remove(at: currentExerciseIndex)

        // Adjust current index if needed
        if currentExerciseIndex >= exercises.count {
            currentExerciseIndex = exercises.count - 1
        }

        // Update completed exercises set
        var newCompleted = Set<Int>()
        for index in completedExercises {
            if index < currentExerciseIndex {
                newCompleted.insert(index)
            } else if index > currentExerciseIndex {
                newCompleted.insert(index - 1)
            }
        }
        completedExercises = newCompleted

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - SuggestionCard

struct SuggestionCard: View {
    let suggestion: KinetiqService.SuggestionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Plateau warning (shown only when detected)
            if let plateau = suggestion.plateauInfo, plateau.isPlateau {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(plateau.explanation)
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(.bottom, 2)
            }

            // Main recommendation
            HStack(spacing: 6) {
                Image(systemName: actionIcon(suggestion.action))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("Next set: \(formattedWeight(suggestion.nextWeight, unit: suggestion.unit)) × \(suggestion.nextReps)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Text(suggestion.explanation)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            // RPE reliability indicator (shown when available and informative)
            if let reliability = suggestion.rpeReliability, reliability.nObservations >= 5 {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                    Text("RPE reliability: \(Int(reliability.score * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func actionIcon(_ action: String) -> String {
        switch action {
        case "add_weight": return "arrow.up.circle"
        case "add_reps":   return "plus.circle"
        case "lower_weight", "lower_reps": return "arrow.down.circle"
        default:           return "arrow.right.circle"
        }
    }

    private func formattedWeight(_ weight: Double, unit: String) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) \(unit)"
        }
        return String(format: "%.1f \(unit)", weight)
    }
}

// MARK: - SetRow

struct SetRow: View {
    let setNumber: Int
    @Binding var set: ExerciseSetInput
    @FocusState private var focusedField: Field?
    @ObservedObject var settings = UserSettings.shared

    enum Field {
        case weight, reps, rpe
    }

    var body: some View {
        HStack(spacing: 12) {
            // Set Number
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)

                Text("\(setNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Weight Input
            VStack(alignment: .leading, spacing: 6) {
                Text("WEIGHT (\(settings.weightUnit.rawValue))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.5))

                TextField("0", text: $set.weight)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .focused($focusedField, equals: .weight)
            }

            // Reps Input
            VStack(alignment: .leading, spacing: 6) {
                Text("REPS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.5))

                TextField("0", text: $set.reps)
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .focused($focusedField, equals: .reps)
            }

            // RPE Input
            VStack(alignment: .leading, spacing: 6) {
                Text("RPE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.5))

                TextField("6-10", text: $set.rpe)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .frame(width: 72)
                    .focused($focusedField, equals: .rpe)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - ConfettiView

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]

        for _ in 0..<100 {
            let randomX = CGFloat.random(in: 0...size.width)
            let randomY = CGFloat.random(in: -100...0)
            let randomColor = colors.randomElement() ?? .white
            let randomSize = CGFloat.random(in: 8...16)

            let piece = ConfettiPiece(
                position: CGPoint(x: randomX, y: randomY),
                color: randomColor,
                size: randomSize
            )

            confettiPieces.append(piece)

            // Animate falling
            withAnimation(.linear(duration: Double.random(in: 2...4))) {
                if let index = confettiPieces.firstIndex(where: { $0.id == piece.id }) {
                    confettiPieces[index].position.y = size.height + 100
                    confettiPieces[index].opacity = 0
                }
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

// MARK: - WorkoutExercise / ExerciseSetInput

struct WorkoutExercise {
    let name: String
    var sets: [ExerciseSetInput]
    let lastPerformance: String?
}

struct ExerciseSetInput {
    var weight: String
    var reps: String
    var rpe: String      // RPE 1–10, optional — leave blank if not logging
    var completed: Bool
}

#Preview {
    ActiveWorkoutView(isPresented: .constant(true), workoutType: "Upper Body")
}
