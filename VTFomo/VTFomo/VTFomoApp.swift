//
//  VTFomoApp.swift
//  VT FOMO
//
//  Creates the app's SwiftData container and passes it to RootView.
//

import SwiftUI
import SwiftData

@main
struct VTFomoApp: App {

    let container: ModelContainer

    @State private var auth = AuthService()

    init() {
        do {
            let schema = Schema([
                AppUser.self,
                Building.self,
                Organization.self,
                Event.self,
                SavedEvent.self
            ])

            #if DEBUG
            let temporaryStore = ProcessInfo.processInfo.arguments.contains("-ui-test-store")
            #else
            let temporaryStore = false
            #endif

            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: temporaryStore
            )

            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
        .modelContainer(container)
    }
}
