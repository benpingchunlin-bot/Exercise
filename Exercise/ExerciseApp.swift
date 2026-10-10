//
//  ExerciseApp.swift
//  Exercise
//
//  Created by Apollo on 2026/9/27.
//

import SwiftUI

@main
struct ExerciseApp: App {
    // Single shared instance; injected into the view hierarchy via @Environment.
    @State private var healthManager = HealthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthManager)
        }
    }
}
