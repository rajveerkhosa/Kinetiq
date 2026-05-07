import SwiftUI

struct ForgotPasswordView: View {
    @Binding var showForgotPassword: Bool
    @Binding var showSignUp: Bool
    @Environment(\.dismiss) var dismiss

    @State private var step = 1
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var didSucceed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                if didSucceed {
                    successView
                } else {
                    topContent
                    if step == 1 { emailStep } else { codeStep }
                }

                Spacer()
            }
        }
    }

    private var topContent: some View {
        VStack(spacing: 10) {
            Image(systemName: step == 1 ? "lock.rotation" : "envelope.badge")
                .font(.system(size: 52))
                .foregroundColor(.white)

            Text(step == 1 ? "Forgot Password?" : "Check Your Email")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(step == 1
                 ? "Enter your email and we'll send a 6-digit reset code."
                 : "Enter the code we sent to \(email) and choose a new password.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            fpField(icon: "envelope.fill", placeholder: "Email address", text: $email, keyboard: .emailAddress)

            if let error = errorMessage { errorBanner(error) }

            Button(action: sendCode) {
                HStack {
                    if isLoading { ProgressView().tint(.black).scaleEffect(0.85) }
                    Text(isLoading ? "Sending..." : "Send Code")
                        .font(.headline).foregroundColor(.black)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(email.isEmpty ? Color.gray.opacity(0.4) : Color.white)
                .cornerRadius(14)
            }
            .disabled(email.isEmpty || isLoading)
            .padding(.horizontal, 24)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            fpField(icon: "number", placeholder: "6-digit code", text: $code, keyboard: .numberPad)
            fpField(icon: "lock.fill", placeholder: "New password", text: $newPassword, isSecure: true)
            fpField(icon: "lock.fill", placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)

            if let error = errorMessage { errorBanner(error) }

            Button(action: resetPassword) {
                HStack {
                    if isLoading { ProgressView().tint(.black).scaleEffect(0.85) }
                    Text(isLoading ? "Resetting..." : "Reset Password")
                        .font(.headline).foregroundColor(.black)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canReset ? Color.white : Color.gray.opacity(0.4))
                .cornerRadius(14)
            }
            .disabled(!canReset || isLoading)
            .padding(.horizontal, 24)

            Button("Resend code") {
                errorMessage = nil
                step = 1
            }
            .font(.footnote).foregroundColor(.white.opacity(0.45))
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Password Reset!")
                .font(.title2.bold()).foregroundColor(.white)

            Text("You can now log in with your new password.")
                .font(.subheadline).foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            Button("Back to Login") { dismiss() }
                .font(.headline).foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.white).cornerRadius(14)
                .padding(.horizontal, 24)
        }
    }

    private var canReset: Bool {
        code.count == 6 && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func sendCode() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/forgot-password") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email.lowercased()])
                _ = try await URLSession.shared.data(for: req)
                await MainActor.run { isLoading = false; step = 2 }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = "Something went wrong. Check your connection." }
            }
        }
    }

    private func resetPassword() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/reset-password") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: [
                    "email": email.lowercased(),
                    "code": code,
                    "new_password": newPassword
                ])
                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    isLoading = false
                    if status == 200 {
                        didSucceed = true
                    } else {
                        let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
                        errorMessage = detail ?? "Invalid or expired code."
                    }
                }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = "Something went wrong." }
            }
        }
    }

    @ViewBuilder
    private func fpField(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.white.opacity(0.4)).frame(width: 18)
            if isSecure {
                SecureField("", text: text)
                    .foregroundColor(.white)
                    .placeholder(when: text.wrappedValue.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.4))
                    }
            } else {
                TextField("", text: text)
                    .foregroundColor(.white)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .placeholder(when: text.wrappedValue.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.4))
                    }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white.opacity(0.08)).cornerRadius(12)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
            Text(msg).font(.footnote).foregroundColor(.red.opacity(0.9))
            Spacer()
        }
        .padding(12).background(Color.red.opacity(0.12)).cornerRadius(10)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ForgotPasswordView(showForgotPassword: .constant(true), showSignUp: .constant(false))
}
