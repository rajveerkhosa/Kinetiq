import SwiftUI

struct WorkoutHistoryView: View {
    @State private var sessions: [APISession] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Workout History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.black)
                    Spacer()
                } else if sessions.isEmpty {
                    Spacer()
                    Text("No workouts logged yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 16) {
                            ForEach(sessions) { session in
                                APIWorkoutHistoryCard(session: session)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .task {
            await fetchHistory()
        }
    }

    func fetchHistory() async {
        let userId = UserDefaults.standard.integer(forKey: "user_id")
        guard userId > 0 else {
            isLoading = false
            return
        }

        guard let url = URL(string: "https://kinetiq-dzfm.onrender.com/sessions/\(userId)") else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sessionList = json["sessions"] as? [[String: Any]] {
                await MainActor.run {
                    sessions = sessionList.compactMap { APISession(from: $0) }
                    isLoading = false
                }
            }
        } catch {
            print("Error fetching history:", error)
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - API Models

struct APISession: Identifiable {
    let id: Int
    let planName: String
    let sessionDate: String
    let startFlag: Bool
    let missFlag: Bool

    init?(from dict: [String: Any]) {
        guard let id = dict["session_id"] as? Int else { return nil }
        self.id = id
        self.planName = dict["plan_name"] as? String ?? "Workout"
        self.sessionDate = dict["session_date"] as? String ?? ""
        self.startFlag = dict["start_workout_flag"] as? Bool ?? false
        self.missFlag = dict["workout_miss_flag"] as? Bool ?? false
    }
}

// MARK: - History Card

struct APIWorkoutHistoryCard: View {
    let session: APISession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.planName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text(formatDate(session.sessionDate))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                if session.missFlag {
                    Text("Missed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(8)
                } else {
                    Text("Completed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateFormat = "MMM d, yyyy"
            return display.string(from: date)
        }
        return dateString
    }
}

#Preview {
    WorkoutHistoryView()
}