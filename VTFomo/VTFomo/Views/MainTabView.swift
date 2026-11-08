//
//  MainTabView.swift
//  VT FOMO
//
//  The shell of the signed-in app, and the place where the two platforms
//  differ (Requirement NFR-5).
//
//    iPhone -> a TabView. One thing at a time, reachable with a thumb.
//    iPad   -> a NavigationSplitView. The event list sits in the sidebar and
//              the map fills the detail pane, so you can scan the list and see
//              where things are at the same time.
//
//  We branch on horizontalSizeClass rather than on the device type, so an iPad
//  in a narrow Split View window correctly falls back to the compact layout.
//

import SwiftUI
import SwiftData

struct MainTabView: View {

    @Environment(\.horizontalSizeClass) private var sizeClass
    let user: AppUser

    /// Shared filter state so the map and the list always agree.
    @State private var options = FilterOptions()
    @State private var selectedEvent: Event?

    var body: some View {
        if sizeClass == .compact {
            compactLayout
        } else {
            regularLayout
        }
    }

    // MARK: - iPhone

    private var compactLayout: some View {
        TabView {
            NavigationStack {
                MapScreen(user: user, options: $options, selectedEvent: $selectedEvent)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }

            NavigationStack {
                EventListScreen(user: user, options: $options)
            }
            .tabItem { Label("Events", systemImage: "calendar") }

            NavigationStack {
                SavedEventsScreen(user: user)
            }
            .tabItem { Label("Saved", systemImage: "bookmark.fill") }

            NavigationStack {
                ProfileScreen(user: user)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Theme.maroon)
    }

    // MARK: - iPad

    private var regularLayout: some View {
        NavigationSplitView {
            EventListScreen(user: user, options: $options, selection: $selectedEvent)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            NavigationStack {
                MapScreen(user: user, options: $options, selectedEvent: $selectedEvent)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.maroon)
    }
}
