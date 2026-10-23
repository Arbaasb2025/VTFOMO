//
//  RootView.swift
//  VT FOMO
//
//  Decides which of the three top-level states the app is in:
//    1. nobody signed in           -> LoginView
//    2. signed in, no hall chosen  -> OnboardingBuildingView
//    3. signed in and set up       -> MainTabView
//
//  Keeping this decision in one place means no other screen has to worry
//  about whether the user is signed in.
//

import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    @State private var isPreparing = true
    /// Separate from `isPreparing` so the launch animation always gets to
    /// finish. Seeding takes about 40ms, and cutting a 1.6s animation off at
    /// 40ms would look like a glitch rather than an intro.
    @State private var showLaunch = true

    var body: some View {
        Group {
            if showLaunch {
                // Requirement NFR-3: never show a blank screen while work is
                // happening. The user always knows something is going on.
                LaunchView(isFinished: !isPreparing)
                    .transition(.opacity)
            } else if let user = auth.currentUser {
                if user.homeBuilding == nil {
                    OnboardingBuildingView(user: user)
                } else {
                    MainTabView(user: user)
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.currentUser?.id)
        .animation(.easeInOut(duration: 0.35), value: showLaunch)
        .task {
            // Real work and the intro run at the same time. Whichever finishes
            // last decides when we move on, so a slow first launch never looks
            // broken and a fast one never feels abrupt.
            async let setup: Void = prepare()
            async let intro: Void = minimumIntro()
            _ = await (setup, intro)
            showLaunch = false
        }
    }

    /// Holds the intro on screen long enough for the animation to land.
    private func minimumIntro() async {
        try? await Task.sleep(for: .milliseconds(1750))
    }

    private func prepare() async {
        SampleData.seedIfNeeded(context: context)
        auth.restoreSession(context: context)
        _ = await NotificationService.requestPermission()
        isPreparing = false
    }
}
