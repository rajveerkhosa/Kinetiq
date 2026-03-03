import SwiftUI

struct RestTimerSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = UserSettings.shared
    @State private var selectedDuration: Int

    let durationOptions = [60, 90, 120, 150, 180, 210, 240, 300]

    init() {
        _selectedDuration = State(initialValue: UserSettings.shared.restTimerDuration)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Select your default rest timer duration")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 20)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Button(action: {
                                    selectedDuration = duration
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(formatDuration(duration))
                                                .font(.headline)
                                                .foregroundColor(.black)

                                            Text("\(duration) seconds")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }

                                        Spacer()

                                        if selectedDuration == duration {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.black)
                                        } else {
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    .padding()
                                    .background(selectedDuration == duration ? Color.black.opacity(0.05) : Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedDuration == duration ? Color.black : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settings.restTimerDuration = selectedDuration
                        dismiss()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if remainingSeconds == 0 {
            return "\(minutes) \(minutes == 1 ? "Minute" : "Minutes")"
        } else {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }
}

#Preview {
    RestTimerSettingsView()
}
