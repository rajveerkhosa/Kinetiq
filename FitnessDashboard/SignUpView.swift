import SwiftUI

struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @Binding var showSignUp: Bool
    @ObservedObject var profile = UserProfile.shared
    @ObservedObject var workoutData = WorkoutDataStore.shared
    @ObservedObject var settings = UserSettings.shared
    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    @State private var passwordError: String? = nil
    @State private var confirmPasswordError: String? = nil

    var passwordRequirements: [(label: String, met: Bool)] {
        [
            ("At least 8 characters", password.count >= 8),
            ("Uppercase letter", password.contains(where: \.isUppercase)),
            ("Lowercase letter", password.contains(where: \.isLowercase)),
            ("Number", password.contains(where: \.isNumber)),
            ("Symbol (!@#$...)", password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }))
        ]
    }

    var isPasswordValid: Bool { passwordRequirements.allSatisfy(\.met) }

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

                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 10)

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

                        // First & Last Name (side by side)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("", text: $firstName)
                                    .foregroundColor(.white)
                                    .placeholder(when: firstName.isEmpty) {
                                        Text("First").foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("", text: $lastName)
                                    .foregroundColor(.white)
                                    .placeholder(when: lastName.isEmpty) {
                                        Text("Last").foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 30)

                        // Middle Name (optional)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Middle Name (Optional)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            TextField("", text: $middleName)
                                .foregroundColor(.white)
                                .placeholder(when: middleName.isEmpty) {
                                    Text("Enter middle name").foregroundColor(.white.opacity(0.5))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)

                        // Username
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            HStack {
                                Image(systemName: "at")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))

                                TextField("", text: $username)
                                    .foregroundColor(.white)
                                    .autocapitalization(.none)
                                    .placeholder(when: username.isEmpty) {
                                        Text("Choose a username").foregroundColor(.white.opacity(0.5))
                                    }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)

                        // Email
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
                                        Text("Enter your email").foregroundColor(.white.opacity(0.5))
                                    }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)

                        // Password
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
                                        Text("Create a password").foregroundColor(.white.opacity(0.5))
                                    }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)

                            // Requirements checklist — only show once user starts typing
                            if !password.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(passwordRequirements, id: \.label) { req in
                                        HStack(spacing: 6) {
                                            Image(systemName: req.met ? "checkmark.circle.fill" : "circle")
                                                .font(.caption)
                                                .foregroundColor(req.met ? .green : .white.opacity(0.4))
                                            Text(req.label)
                                                .font(.caption)
                                                .foregroundColor(req.met ? .green : .white.opacity(0.5))
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 30)

                        // Confirm Password
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
                                        Text("Re-enter your password").foregroundColor(.white.opacity(0.5))
                                    }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)

                            if !confirmPassword.isEmpty && confirmPassword != password {
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 30)

                        // Terms and Conditions
                        HStack(alignment: .top, spacing: 8) {
                            Button(action: { agreeToTerms.toggle() }) {
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

                        // Create Account Button
                        Button(action: {
                            guard isPasswordValid, password == confirmPassword else { return }

                            UserDefaults.standard.set(email, forKey: "pendingEmail")
                            UserDefaults.standard.set(password, forKey: "pendingPassword")

                            workoutData.resetAllData()
                            settings.weightUnit = .imperial
                            settings.restTimerDuration = 120
                            profile.resetPlan()

                            if let bundleID = Bundle.main.bundleIdentifier {
                                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                            }

                            UserDefaults.standard.set(email, forKey: "pendingEmail")
                            UserDefaults.standard.set(password, forKey: "pendingPassword")
                            UserDefaults.standard.set(username, forKey: "pendingUsername")
                            UserDefaults.standard.set(firstName, forKey: "pendingFirstName")
                            UserDefaults.standard.set(middleName.isEmpty ? "" : middleName, forKey: "pendingMiddleName")
                            UserDefaults.standard.set(lastName, forKey: "pendingLastName")

                            let fullName = middleName.isEmpty
                                ? "\(firstName) \(lastName)"
                                : "\(firstName) \(middleName) \(lastName)"
                            profile.fullName = fullName.trimmingCharacters(in: .whitespaces)

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
                                .background(agreeToTerms && isPasswordValid && password == confirmPassword ? Color.white : Color.white.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .disabled(!agreeToTerms || !isPasswordValid || password != confirmPassword)
                        .padding(.horizontal, 30)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                            Text("OR").font(.caption).foregroundColor(.white.opacity(0.5)).padding(.horizontal, 8)
                            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                        }
                        .padding(.horizontal, 30)

                        // Social Sign Up
                        VStack(spacing: 8) {
                            SocialLoginButton(icon: "apple.logo", title: "Sign up with Apple", backgroundColor: .white.opacity(0.1))
                            SocialLoginButton(icon: "g.circle.fill", title: "Sign up with Google", backgroundColor: .white.opacity(0.1))
                        }
                        .padding(.horizontal, 30)

                        // Login Link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.7))
                            Button(action: { showSignUp = false }) {
                                Text("Log In").fontWeight(.semibold).foregroundColor(.white)
                            }
                        }
                        .font(.subheadline)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false), showSignUp: .constant(true))
}
