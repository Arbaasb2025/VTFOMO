//
//  VTFomoApp.swift
//  VT FOMO
//
//  App entry point. Builds the SwiftData container, seeds sample data on
//  first launch, and hands control to RootView.
//

import SwiftUI
import SwiftData

@main
struct VTFomoApp: App {

    /// One shared container for the whole app.
    let container: ModelContainer

    /// Services live at the top of the tree and are passed down through the
    /// environment so any screen can reach them without prop drilling.
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
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If the store cannot be opened the app cannot function, so failing
            // loudly here is better than limping along with no persistence.
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
