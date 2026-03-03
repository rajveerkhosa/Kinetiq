import SwiftUI

struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @Binding var showSignUp: Bool
    @ObservedObject var profile = UserProfile.shared
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @ObservedObject var settings = UserSettings.shared
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button(action: {
                        showSignUp = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding()

                VStack(spacing: 20) {
                    Spacer()

                    // Logo/Icon
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    // Title
                    VStack(spacing: 6) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Start your fitness journey today")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 5)

                    // Full Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Full Name")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))

                            TextField("", text: $fullName)
                                .foregroundColor(.white)
                                .placeholder(when: fullName.isEmpty) {
                                    Text("Enter your full name")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))

                            TextField("", text: $email)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .placeholder(when: email.isEmpty) {
                                    Text("Enter your email")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    // Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))

                            SecureField("", text: $password)
                                .foregroundColor(.white)
                                .placeholder(when: password.isEmpty) {
                                    Text("Create a password")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))

                            SecureField("", text: $confirmPassword)
                                .foregroundColor(.white)
                                .placeholder(when: confirmPassword.isEmpty) {
                                    Text("Re-enter your password")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    // Terms and Conditions
                    HStack(alignment: .top, spacing: 8) {
                        Button(action: {
                            agreeToTerms.toggle()
                        }) {
                            Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(agreeToTerms ? .white : .white.opacity(0.5))
                        }

                        Text("I agree to the Terms of Service and Privacy Policy")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 30)

                    // Sign Up Button
                    Button(action: {
                        // Clear ALL data for new account
                        workoutData.resetAllData()
                        settings.weightUnit = .imperial
                        settings.restTimerDuration = 120
                        profile.resetPlan()

                        // Clear all UserDefaults completely
                        if let bundleID = Bundle.main.bundleIdentifier {
                            UserDefaults.standard.removePersistentDomain(forName: bundleID)
                        }

                        // Save user's name
                        profile.fullName = fullName.isEmpty ? nil : fullName

                        // Simple signup - just set authenticated to true
                        withAnimation {
                            isAuthenticated = true
                            showSignUp = false
                        }
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(agreeToTerms ? Color.white : Color.white.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .disabled(!agreeToTerms)
                    .padding(.horizontal, 30)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)

                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 8)

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 30)

                    // Social Sign Up Buttons
                    VStack(spacing: 8) {
                        SocialLoginButton(
                            icon: "apple.logo",
                            title: "Sign up with Apple",
                            backgroundColor: .white.opacity(0.1)
                        )

                        SocialLoginButton(
                            icon: "g.circle.fill",
                            title: "Sign up with Google",
                            backgroundColor: .white.opacity(0.1)
                        )
                    }
                    .padding(.horizontal, 30)

                    Spacer()

                    // Login Link
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            showSignUp = false
                        }) {
                            Text("Log In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .font(.subheadline)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false), showSignUp: .constant(true))
}
