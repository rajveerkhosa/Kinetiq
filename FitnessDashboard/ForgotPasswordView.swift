import SwiftUI

struct ForgotPasswordView: View {
    @Binding var showForgotPassword: Bool
    @Binding var showSignUp: Bool
    @State private var email = ""
    @State private var isEmailSent = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button(action: {
                        showForgotPassword = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding()

                if isEmailSent {
                    // Success State
                    VStack(spacing: 30) {
                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)

                        VStack(spacing: 12) {
                            Text("Check Your Email")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("We've sent password reset instructions to")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)

                            Text(email)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 40)

                        Button(action: {
                            showForgotPassword = false
                        }) {
                            Text("Back to Login")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)

                        Spacer()
                    }
                } else {
                    // Email Input State
                    VStack(spacing: 25) {
                        Spacer()

                        // Icon
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)

                        // Title
                        VStack(spacing: 8) {
                            Text("Forgot Password?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("Enter your email and we'll send you instructions to reset your password")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .padding(.bottom, 20)

                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
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

                        // Reset Button
                        Button(action: {
                            withAnimation {
                                isEmailSent = true
                            }
                        }) {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(email.isEmpty ? Color.white.opacity(0.5) : Color.white)
                                .cornerRadius(12)
                        }
                        .disabled(email.isEmpty)
                        .padding(.horizontal, 30)

                        // Back to Login
                        Button(action: {
                            showForgotPassword = false
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                Text("Back to Login")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 10)

                        Spacer()

                        // Sign Up Link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.white.opacity(0.7))

                            Button(action: {
                                showForgotPassword = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showSignUp = true
                                }
                            }) {
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
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
    ForgotPasswordView(showForgotPassword: .constant(true), showSignUp: .constant(false))
}
