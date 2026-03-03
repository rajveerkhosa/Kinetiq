import SwiftUI
import HealthKit

struct OnboardingBasicsView: View {
    @ObservedObject var profile = UserProfile.shared
    @Binding var currentStep: OnboardingStep
    @State private var currentPage = 0
    @State private var showHealthKitAlert = false

    private let totalPages = 8
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color.white : Color.white.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 50)
                .padding(.bottom, 30)

                // Content
                TabView(selection: $currentPage) {
                    HealthKitPermissionPageModern(showAlert: $showHealthKitAlert).tag(0)
                    SexSelectionPageModern(profile: profile).tag(1)
                    BirthDateSelectionPageModern(profile: profile).tag(2)
                    HeightSelectionPageModern(profile: profile).tag(3)
                    WeightSelectionPageModern(profile: profile).tag(4)
                    BodyFatSelectionPageModern(profile: profile).tag(5)
                    ExperienceSelectionPageModern(
                        title: "Lifting Experience",
                        subtitle: "Your strength training background",
                        selectedLevel: Binding(
                            get: { profile.liftingExperience },
                            set: { profile.liftingExperience = $0 }
                        )
                    ).tag(6)
                    ExperienceSelectionPageModern(
                        title: "Cardio Fitness",
                        subtitle: "Your cardiovascular fitness level",
                        selectedLevel: Binding(
                            get: { profile.cardioLevel },
                            set: { profile.cardioLevel = $0 }
                        )
                    ).tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    hapticImpact.impactOccurred()
                }

                // Modern navigation
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentPage -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }

                    Button(action: {
                        if currentPage < totalPages - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            currentStep = .program
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(currentPage < totalPages - 1 ? "Continue" : "Next")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canContinue ? Color.white : Color.white.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .disabled(!canContinue)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("Health Data", isPresented: $showHealthKitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable Health access in Settings to sync your data.")
        }
    }

    private var canContinue: Bool {
        switch currentPage {
        case 0: return true
        case 1: return profile.sex != nil
        case 2: return profile.birthDate != nil
        case 3: return profile.heightCm != nil
        case 4: return profile.weightKg != nil
        case 5: return profile.bodyFatLevel != nil
        case 6: return profile.liftingExperience != nil
        case 7: return profile.cardioLevel != nil
        default: return false
        }
    }
}

// MARK: - Modern Pages

struct HealthKitPermissionPageModern: View {
    @Binding var showAlert: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Connect Apple Health")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Sync your health data for personalized insights")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                requestHealthKitAuthorization()
            }) {
                Text("Connect Health")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.pink, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showAlert = true
            return
        }

        let healthStore = HKHealthStore()
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if success {
                // Fetch data in background
            }
        }
    }
}

struct SexSelectionPageModern: View {
    @ObservedObject var profile: UserProfile

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Biological Sex")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("This helps us personalize your program")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 12) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            profile.sex = sex
                        }
                    }) {
                        HStack {
                            Text(sex.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(profile.sex == sex ? .black : .white)

                            Spacer()

                            if profile.sex == sex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.black)
                                    .font(.system(size: 22))
                            }
                        }
                        .padding(20)
                        .background(profile.sex == sex ? Color.white : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct BirthDateSelectionPageModern: View {
    @ObservedObject var profile: UserProfile
    @State private var selectedDate: Date

    init(profile: UserProfile) {
        self.profile = profile
        // Initialize with a reasonable default date (18 years ago)
        let eighteenYearsAgo = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        _selectedDate = State(initialValue: profile.birthDate ?? eighteenYearsAgo)
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Date of Birth")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("This helps personalize your program")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
            }

            DatePicker("", selection: Binding(
                get: { profile.birthDate ?? selectedDate },
                set: {
                    selectedDate = $0
                    profile.birthDate = $0
                }
            ), displayedComponents: .date)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct HeightSelectionPageModern: View {
    @ObservedObject var profile: UserProfile
    @State private var isMetric = false // Default to imperial
    @State private var selectedFeet: Int = 5
    @State private var selectedInches: Int = 8
    @State private var selectedCm: Int = 170

    let feetOptions = Array(3...8)
    let inchesOptions = Array(0...11)
    let cmOptions = Array(100...250)

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("What is your height?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Unit toggle
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMetric = false
                    }
                }) {
                    Text("Feet and Inches")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(!isMetric ? .black : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(!isMetric ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMetric = true
                    }
                }) {
                    Text("Centimeters")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isMetric ? .black : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isMetric ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
            }
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .padding(.top, 20)

            if isMetric {
                // CM picker
                Picker("", selection: $selectedCm) {
                    ForEach(cmOptions, id: \.self) { cm in
                        Text("\(cm) cm")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .tag(cm)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .colorScheme(.dark)
                .onChange(of: selectedCm) { _, newValue in
                    profile.heightCm = Double(newValue)
                }
            } else {
                // Feet and Inches pickers side by side
                HStack(spacing: 0) {
                    Picker("", selection: $selectedFeet) {
                        ForEach(feetOptions, id: \.self) { feet in
                            Text("\(feet) ft")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .tag(feet)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 150, height: 200)
                    .colorScheme(.dark)
                    .onChange(of: selectedFeet) { _, _ in
                        updateHeightFromImperial()
                    }

                    Picker("", selection: $selectedInches) {
                        ForEach(inchesOptions, id: \.self) { inches in
                            Text("\(inches) in")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .tag(inches)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 150, height: 200)
                    .colorScheme(.dark)
                    .onChange(of: selectedInches) { _, _ in
                        updateHeightFromImperial()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            if let heightCm = profile.heightCm {
                selectedCm = Int(heightCm)
                let totalInches = heightCm / 2.54
                selectedFeet = Int(totalInches / 12)
                selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            } else {
                updateHeightFromImperial()
            }
        }
    }

    private func updateHeightFromImperial() {
        let totalInches = Double(selectedFeet * 12 + selectedInches)
        let heightInCm = totalInches * 2.54
        profile.heightCm = heightInCm
        selectedCm = Int(heightInCm)
    }
}

struct WeightSelectionPageModern: View {
    @ObservedObject var profile: UserProfile
    @State private var selectedWeightLbs: Double = 154.0
    @State private var selectedWeightKg: Double = 70.0
    @State private var isMetric = false // Default to imperial

    // Weight options with 0.1 precision (60.0 to 1000 lbs, 27 to 453 kg)
    let lbsOptions: [Double] = {
        stride(from: 60.0, through: 1000.0, by: 0.1).map { $0 }
    }()

    let kgOptions: [Double] = {
        stride(from: 27.0, through: 453.0, by: 0.1).map { $0 }
    }()

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("What is your weight?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Unit toggle
            HStack(spacing: 0) {
                Button(action: {
                    if isMetric {
                        selectedWeightLbs = selectedWeightKg * 2.205
                        isMetric = false
                    }
                }) {
                    Text("Pounds")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(!isMetric ? .black : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(!isMetric ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }

                Button(action: {
                    if !isMetric {
                        selectedWeightKg = selectedWeightLbs / 2.205
                        isMetric = true
                    }
                }) {
                    Text("Kilograms")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isMetric ? .black : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isMetric ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
            }
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .padding(.top, 20)

            // Weight picker
            if isMetric {
                Picker("", selection: $selectedWeightKg) {
                    ForEach(kgOptions, id: \.self) { kg in
                        Text(String(format: "%.1f kg", kg))
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .colorScheme(.dark)
                .onChange(of: selectedWeightKg) { _, newValue in
                    profile.weightKg = newValue
                    selectedWeightLbs = newValue * 2.205
                }
            } else {
                Picker("", selection: $selectedWeightLbs) {
                    ForEach(lbsOptions, id: \.self) { lbs in
                        Text(String(format: "%.1f lbs", lbs))
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .tag(lbs)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .colorScheme(.dark)
                .onChange(of: selectedWeightLbs) { _, newValue in
                    profile.weightKg = newValue / 2.205
                    selectedWeightKg = newValue / 2.205
                }
            }

            Spacer()
        }
        .onAppear {
            if let weightKg = profile.weightKg {
                selectedWeightKg = weightKg
                selectedWeightLbs = weightKg * 2.205
            } else {
                profile.weightKg = selectedWeightLbs / 2.205
            }
        }
    }
}

// MARK: - Horizontal Number Picker

struct HorizontalNumberPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Center indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)

                // Numbers
                HStack(spacing: 20) {
                    ForEach(numbers, id: \.self) { number in
                        Text(formatNumber(number))
                            .font(.system(size: numberSize(for: number, geometry: geometry), weight: .semibold, design: .rounded))
                            .foregroundColor(numberColor(for: number, geometry: geometry))
                            .frame(width: 60)
                    }
                }
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let newOffset = offset + value.translation.width
                            offset = newOffset
                            updateValue(for: geometry.size.width)
                        }
                )
            }
            .onAppear {
                let index = numbers.firstIndex(where: { abs($0 - value) < 0.01 }) ?? 0
                offset = -CGFloat(index) * 80 + geometry.size.width / 2
            }
        }
    }

    private var numbers: [Double] {
        stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
    }

    private func formatNumber(_ number: Double) -> String {
        if step >= 1 {
            return String(format: "%.0f", number)
        } else {
            return String(format: "%.1f", number)
        }
    }

    private func numberSize(for number: Double, geometry: GeometryProxy) -> CGFloat {
        let center = geometry.size.width / 2
        let numberOffset = offset + dragOffset + CGFloat(numbers.firstIndex(where: { abs($0 - number) < 0.01 }) ?? 0) * 80
        let distance = abs(center - numberOffset)
        return max(16, 28 - distance / 20)
    }

    private func numberColor(for number: Double, geometry: GeometryProxy) -> Color {
        let center = geometry.size.width / 2
        let numberOffset = offset + dragOffset + CGFloat(numbers.firstIndex(where: { abs($0 - number) < 0.01 }) ?? 0) * 80
        let distance = abs(center - numberOffset)
        let opacity = max(0.2, 1 - distance / 100)
        return Color.white.opacity(opacity)
    }

    private func updateValue(for width: CGFloat) {
        let center = width / 2
        let index = Int(round((center - offset) / 80))
        if index >= 0 && index < numbers.count {
            value = numbers[index]
        }
    }
}

struct BodyFatSelectionPageModern: View {
    @ObservedObject var profile: UserProfile

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Body Fat Level")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Estimated visual reference")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.6))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(BodyFatLevel.allCases, id: \.self) { level in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.bodyFatLevel = level
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(level.rawValue)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(profile.bodyFatLevel == level ? .black : .white)

                                        Text(genderSpecificDescription(for: level))
                                            .font(.system(size: 14))
                                            .foregroundColor(profile.bodyFatLevel == level ? .black.opacity(0.6) : .white.opacity(0.5))
                                    }

                                    Spacer()

                                    if profile.bodyFatLevel == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.black)
                                            .font(.system(size: 22))
                                    }
                                }
                            }
                            .padding(20)
                            .background(profile.bodyFatLevel == level ? Color.white : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func genderSpecificDescription(for level: BodyFatLevel) -> String {
        let isMale = profile.sex == .male
        let isFemale = profile.sex == .female

        switch level {
        case .veryLean:
            if isMale {
                return "6-10%"
            } else if isFemale {
                return "14-18%"
            } else {
                return "6-10% (M) / 14-18% (F)"
            }
        case .lean:
            if isMale {
                return "11-14%"
            } else if isFemale {
                return "19-22%"
            } else {
                return "11-14% (M) / 19-22% (F)"
            }
        case .average:
            if isMale {
                return "15-19%"
            } else if isFemale {
                return "23-27%"
            } else {
                return "15-19% (M) / 23-27% (F)"
            }
        case .aboveAverage:
            if isMale {
                return "20-24%"
            } else if isFemale {
                return "28-32%"
            } else {
                return "20-24% (M) / 28-32% (F)"
            }
        case .high:
            if isMale {
                return "25%+"
            } else if isFemale {
                return "33%+"
            } else {
                return "25%+ (M) / 33%+ (F)"
            }
        }
    }
}

struct ExperienceSelectionPageModern: View {
    let title: String
    let subtitle: String
    @Binding var selectedLevel: ExperienceLevel?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedLevel = level
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Icon circle
                                Circle()
                                    .fill(selectedLevel == level ? Color.black : Color.white.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: level.icon)
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedLevel == level ? .white : .white.opacity(0.6))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.rawValue)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(selectedLevel == level ? .black : .white)

                                    Text(level.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(selectedLevel == level ? .black.opacity(0.6) : .white.opacity(0.5))
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                if selectedLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.black)
                                        .font(.system(size: 24))
                                }
                            }
                            .padding(20)
                            .background(selectedLevel == level ? Color.white : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedLevel == level ? Color.white.opacity(0.3) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Spacer()
        }
    }
}

#Preview {
    OnboardingBasicsView(currentStep: .constant(.basics))
}
