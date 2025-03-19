//
//  Speech2CodeApp.swift
//  Speech2Code
//
//  Created by Chris Beavis on 13/03/2025.
//

import SwiftUI
import SwiftData

@main
struct Speech2CodeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Microphone permissions on macOS are handled at the OS level
        // when the app first attempts to access the microphone
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
