//
//  ContentView.swift
//  Exercise
//

import SwiftUI

struct ContentView: View {
    @Environment(HealthManager.self) private var healthManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                switch healthManager.dataState {
                case .notDetermined, .loading:
                    ProgressView()
                        .controlSize(.large)
                case .loaded:
                    loadedView
                case .denied:
                    deniedView
                case .unavailable:
                    unavailableView
                }
            }
            .navigationTitle("Steps")
            .navigationBarTitleDisplayMode(.large)
        }
        // Request permission and load data when the view first appears.
        .task {
            await healthManager.requestAuthorizationAndLoad()
        }
        // Refresh whenever the app returns to the foreground.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await healthManager.refresh() }
            }
        }
    }

    // MARK: - Loaded state

    private var loadedView: some View {
        ScrollView {
            VStack(spacing: 32) {
                todayCard
                StepBarChart(days: healthManager.weekSteps)
            }
            .padding()
        }
        .refreshable {
            await healthManager.refresh()
        }
    }

    /// Large, prominent display of today's step count.
    private var todayCard: some View {
        VStack(spacing: 6) {
            Text("\(healthManager.todaySteps)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("Steps Today")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Show which devices/apps contributed (e.g. "Garmin Connect, Apollo's iPhone").
            if !healthManager.todaySources.isEmpty {
                Text(healthManager.todaySources.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Error / empty states

    /// Shown when the user has denied HealthKit access.
    private var deniedView: some View {
        ContentUnavailableView {
            Label("Health Access Required", systemImage: "heart.slash")
        } description: {
            Text("Please allow Exercise to access your step count in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Shown on devices where HealthKit is not available (e.g. iPad without Health app).
    private var unavailableView: some View {
        ContentUnavailableView(
            "Health Not Available",
            systemImage: "heart.slash",
            description: Text("Apple Health is not available on this device.")
        )
    }
}

#Preview {
    ContentView()
}
