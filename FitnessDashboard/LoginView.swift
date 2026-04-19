import SwiftUI

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 25) {
                Spacer()

                // Logo/Icon
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 70))
                    .foregroundColor(.white)

                // Title
                VStack(spacing: 6) {
                    Text("Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Log in to continue your fitness journey")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 10)

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
                                Text("Enter your password")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 30)

                // Forgot Password
                HStack {
                    Spacer()
                    Button(action: {
                        showForgotPassword = true
                    }) {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 30)

                // Login Button
  Button(action: {
    Task {
        do {
            guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/login") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["email": email, "password": password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let user = json["user"] as? [String: Any],
                   let userId = user["user_id"] as? Int {
                    UserDefaults.standard.set(userId, forKey: "user_id")
                }
		// Fetch active plan
                    if let planUrl = URL(string: "https://kinetiq-dzfm.onrender.com/plans/\(userId)/active") {
                        let (planData, _) = try await URLSession.shared.data(from: planUrl)
                        if let planJson = try? JSONSerialization.jsonObject(with: planData) as? [String: Any],
                           let plan = planJson["plan"] as? [String: Any],
                           let planId = plan["plan_id"] as? Int {
                            UserDefaults.standard.set(planId, forKey: "active_plan_id")
                        }
                    }
                }
                await MainActor.run {
                    withAnimation {
                        isAuthenticated = true
                    }
                }
            }
        } catch {
            print("Login error:", error)
        }
    }
}) {
    Text("Log In")
        .font(.headline)
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
}
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

                // Social Login Buttons
                VStack(spacing: 10) {
                    SocialLoginButton(
                        icon: "apple.logo",
                        title: "Continue with Apple",
                        backgroundColor: .white.opacity(0.1)
                    )

                    SocialLoginButton(
                        icon: "g.circle.fill",
                        title: "Continue with Google",
                        backgroundColor: .white.opacity(0.1)
                    )
                }
                .padding(.horizontal, 30)

                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: {
                        showSignUp = true
                    }) {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .font(.subheadline)

                Spacer()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated, showSignUp: $showSignUp)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(showForgotPassword: $showForgotPassword, showSignUp: $showSignUp)
        }
    }
}

struct SocialLoginButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color

    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

// Helper extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    LoginView(isAuthenticated: .constant(false))
}
