import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var selectedTab = 1
    @ObservedObject var profile = UserProfile.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !isAuthenticated {
                LoginView(isAuthenticated: $isAuthenticated)
            } else if !profile.hasCompletedOnboarding {
                OnboardingContainerView()
            } else {
                TabView(selection: $selectedTab) {
                    ProgressView()
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Progress")
                        }
                        .tag(0)

                    KinetiqView()
                        .tabItem {
                            Image(systemName: "square.grid.2x2")
                            Text("Dashboard")
                        }
                        .tag(1)

                    NutritionLogView()
                        .tabItem {
                            Image(systemName: "fork.knife")
                            Text("Nutrition")
                        }
                        .tag(2)

                    StrengthView()
                        .tabItem {
                            Image(systemName: "dumbbell.fill")
                            Text("Strength")
                        }
                        .tag(3)

                    AccountView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Account")
                        }
                        .tag(4)
                }
                .accentColor(.black)
            }
        }
        .animation(nil, value: isAuthenticated)
        .animation(nil, value: profile.hasCompletedOnboarding)
    }
}

struct DashboardView: View {
    @State private var showConsumed = true
    let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FRIDAY, FEBRUARY 6")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .tracking(1.5)

                        Text("DASHBOARD")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Weekly Nutrition
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weekly Nutrition")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        // Calendar Grid
                        HStack(spacing: 0) {
                            ForEach(0..<7) { index in
                                VStack(spacing: 8) {
                                    ForEach(0..<4) { row in
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(index == 4 && row == 0 ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                            .frame(height: 50)
                                            .overlay(
                                                Text("—")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            )
                                    }

                                    Text(daysOfWeek[index])
                                        .font(.caption)
                                        .foregroundColor(index == 4 ? .cyan : .gray)
                                        .fontWeight(index == 4 ? .bold : .regular)
                                }
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Rectangle()
                                        .stroke(index == 4 ? Color.cyan : Color.clear, lineWidth: 2)
                                        .cornerRadius(8)
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Nutrition Stats
                        VStack(alignment: .trailing, spacing: 12) {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("0")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                }
                                .foregroundColor(.white)
                                Text("of 2008")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Spacer()
                                Text("0 P")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("of 174")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Spacer()
                                Text("0 F")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("of 66")
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Spacer()
                                Text("0 C")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("of 176")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)

                        // Toggle
                        HStack(spacing: 0) {
                            Button(action: { showConsumed = true }) {
                                Text("Consumed")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(showConsumed ? .black : .white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 32)
                                    .background(showConsumed ? Color.white : Color.clear)
                                    .cornerRadius(20)
                            }

                            Button(action: { showConsumed = false }) {
                                Text("Remaining")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(!showConsumed ? .black : .white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 32)
                                    .background(!showConsumed ? Color.white : Color.clear)
                                    .cornerRadius(20)
                            }
                        }
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(25)
                        .padding(.horizontal)
                    }

                    // Insights & Analytics
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Insights & Analytics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Spacer()

                            Button("See All") {
                                // Action
                            }
                            .foregroundColor(.cyan)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                // Expenditure Card
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Expenditure")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("Last 7 Days")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    // Simple chart representation
                                    HStack(alignment: .bottom, spacing: 4) {
                                        ForEach(0..<7) { _ in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.orange.opacity(0.6))
                                                .frame(width: 30, height: CGFloat.random(in: 20...40))
                                        }
                                    }
                                    .frame(height: 50)

                                    Spacer()

                                    HStack {
                                        Text("2729")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("kcal")
                                            .foregroundColor(.gray)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .frame(width: 280, height: 200)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)

                                // Weight Trend Card
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Weight Trend")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("Last 7 Days")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    // Simple line chart representation
                                    GeometryReader { geometry in
                                        Path { path in
                                            let points: [CGFloat] = [0.6, 0.8, 0.7, 0.75, 0.8, 0.85, 0.9]
                                            let width = geometry.size.width
                                            let height = geometry.size.height
                                            let xStep = width / CGFloat(points.count - 1)

                                            path.move(to: CGPoint(x: 0, y: height * (1 - points[0])))

                                            for (index, point) in points.enumerated() {
                                                let x = CGFloat(index) * xStep
                                                let y = height * (1 - point)
                                                path.addLine(to: CGPoint(x: x, y: y))
                                            }
                                        }
                                        .stroke(Color.purple, lineWidth: 3)

                                        // Add dots
                                        ForEach(0..<7) { index in
                                            let points: [CGFloat] = [0.6, 0.8, 0.7, 0.75, 0.8, 0.85, 0.9]
                                            let width = geometry.size.width
                                            let height = geometry.size.height
                                            let xStep = width / CGFloat(points.count - 1)
                                            let x = CGFloat(index) * xStep
                                            let y = height * (1 - points[index])

                                            Circle()
                                                .fill(Color.purple)
                                                .frame(width: 8, height: 8)
                                                .position(x: x, y: y)
                                        }
                                    }
                                    .frame(height: 50)

                                    Spacer()

                                    HStack {
                                        Text("208.1")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("lbs")
                                            .foregroundColor(.gray)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .frame(width: 280, height: 200)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        Text("Search for a food")
                            .foregroundColor(.gray)

                        Spacer()

                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
