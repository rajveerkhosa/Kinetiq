import SwiftUI

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var identifier = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var loginError: String? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Logo
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 64))
                        .foregroundColor(.white)

                    // Title
                    VStack(spacing: 6) {
                        Text("Welcome Back")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                        Text("Log in to continue your fitness journey")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 8)

                    // Fields
                    VStack(spacing: 14) {
                        inputField(icon: "person.fill", placeholder: "Email or Username") {
                            TextField("", text: $identifier)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .placeholder(when: identifier.isEmpty) {
                                    Text("Email or Username").foregroundColor(.white.opacity(0.4))
                                }
                        }

                        inputField(icon: "lock.fill", placeholder: "Password") {
                            SecureField("", text: $password)
                                .foregroundColor(.white)
                                .placeholder(when: password.isEmpty) {
                                    Text("Password").foregroundColor(.white.opacity(0.4))
                                }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Forgot password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") { showForgotPassword = true }
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)

                    // Error banner
                    if let error = loginError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red.opacity(0.9))
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                    }

                    // Log In button
                    Button(action: handleLogin) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.black).scaleEffect(0.85)
                            }
                            Text(isLoading ? "Logging in..." : "Log In")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        Text("OR").font(.caption).foregroundColor(.white.opacity(0.4)).padding(.horizontal, 10)
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // Social buttons (disabled until credentials set up)
                    VStack(spacing: 10) {
                        SocialLoginButton(icon: "apple.logo", title: "Continue with Apple", backgroundColor: .white.opacity(0.08))
                        SocialLoginButton(icon: "g.circle.fill", title: "Continue with Google", backgroundColor: .white.opacity(0.08))
                    }
                    .padding(.horizontal, 24)
                    .opacity(0.5)
                    .disabled(true)

                    // Sign up link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundColor(.white.opacity(0.6))
                        Button("Sign Up") { showSignUp = true }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .font(.subheadline)

                    Spacer().frame(height: 30)
                }
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated, showSignUp: $showSignUp)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(showForgotPassword: $showForgotPassword, showSignUp: $showSignUp)
        }
    }

    @ViewBuilder
    private func inputField<F: View>(icon: String, placeholder: String, @ViewBuilder field: () -> F) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 18)
            field()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func handleLogin() {
        loginError = nil
        isLoading = true
        Task {
            do {
                guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/login") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["identifier": identifier, "password": password])

                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode

                await MainActor.run { isLoading = false }

                if status == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let user = json["user"] as? [String: Any],
                       let userId = user["user_id"] as? Int {
                        UserDefaults.standard.set(userId, forKey: "user_id")
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
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { isAuthenticated = true }
                    }
                } else {
                    let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
                    await MainActor.run {
                        loginError = detail ?? "Incorrect email or password."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    loginError = "Something went wrong. Check your connection."
                }
            }
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
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.subheadline).fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

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
