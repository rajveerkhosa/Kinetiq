import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var profile = UserProfile.shared
    @State private var currentStep: OnboardingStep = .start

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            switch currentStep {
            case .start:
                OnboardingStartView(currentStep: $currentStep)
                    .transition(.opacity)

            case .basics:
                OnboardingBasicsView(currentStep: $currentStep)
                    .transition(.opacity)

            case .program:
                OnboardingProgramView(currentStep: $currentStep)
                    .transition(.opacity)

            case .complete:
                // This case is handled by the parent view checking hasCompletedOnboarding
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

#Preview {
    OnboardingContainerView()
}
