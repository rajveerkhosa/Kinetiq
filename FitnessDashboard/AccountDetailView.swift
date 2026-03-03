import SwiftUI

struct AccountDetailView: View {
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white)

                ScrollView {
                    VStack(spacing: 20) {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))

                            Text("No workouts recorded yet. Start logging your first workout!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 60)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

#Preview {
    AccountDetailView()
}
