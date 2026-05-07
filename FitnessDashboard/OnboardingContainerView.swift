import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var profile = UserProfile.shared
    @State private var currentStep: OnboardingStep = .start

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                OnboardingCompleteView {
                    profile.hasCompletedOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

struct OnboardingCompleteView: View {
    let onFinish: () -> Void

    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var particles: [ParticleData] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Confetti particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }

            VStack(spacing: 28) {
                Spacer()

                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 110, height: 110)
                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.black)
                }
                .scaleEffect(checkScale)
                .opacity(checkOpacity)

                VStack(spacing: 10) {
                    Text("You're all set!")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(titleOpacity)

                    Text("Let's start building your best self.")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            spawnParticles()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkScale = 1
                checkOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                titleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.75)) {
                subtitleOpacity = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onFinish()
            }
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [.white, .gray, Color(white: 0.85), Color(white: 0.6)]
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        particles = (0..<30).map { i in
            var p = ParticleData(
                x: CGFloat.random(in: 0...screenW),
                y: CGFloat.random(in: screenH * 0.05...screenH * 0.45),
                size: CGFloat.random(in: 4...10),
                color: colors.randomElement()!,
                opacity: Double.random(in: 0.5...1.0)
            )
            withAnimation(.easeOut(duration: Double.random(in: 1.0...2.0)).delay(Double(i) * 0.04)) {
                p.y += CGFloat.random(in: 40...120)
                p.opacity = 0
            }
            return p
        }
    }
}

struct ParticleData: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}

#Preview {
    OnboardingContainerView()
}
