import SwiftUI

struct OnboardingStartView: View {
    @Binding var currentStep: OnboardingStep

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        // Close action - would dismiss onboarding
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: {
                        // Menu action
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                .padding()

                Spacer()

                // Main content
                VStack(spacing: 24) {
                    Text("LET'S GET STARTED")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .tracking(2)

                    Text("Your personalized program awaits")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 60)

                // Steps
                VStack(alignment: .leading, spacing: 32) {
                    // Step 1
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)

                            Text("1")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Basics")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("We'll gather key details like your height and weight to personalize your program to you.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Connector line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 40)
                        .padding(.leading, 24)

                    // Step 2
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 50, height: 50)

                            Text("2")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Text("Gym & Equipment")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Connector line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 40)
                        .padding(.leading, 24)

                    // Step 3
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 50, height: 50)

                            Text("3")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Text("Program")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Continue button
                Button(action: {
                    currentStep = .basics
                }) {
                    Text("Go to Basics")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

enum OnboardingStep {
    case start
    case basics
    case program
    case complete
}

#Preview {
    OnboardingStartView(currentStep: .constant(.start))
}
