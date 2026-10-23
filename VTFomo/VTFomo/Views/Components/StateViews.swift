//
//  StateViews.swift
//  VT FOMO
//
//  Small reusable views for the states a screen can be in: loading, empty,
//  and offline. Having one version of each keeps them consistent everywhere
//  (HIG: consistency) and satisfies the "loading state" requirement.
//

import SwiftUI

/// Shown while data is being fetched.
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.maroon)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

/// Shown when a list has nothing in it. The action button is optional.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Theme.maroon.opacity(0.6))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.maroon)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Thin banner across the top when cached data is being shown.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing saved events")
                .font(.footnote.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.burntOrange.opacity(0.18))
        .foregroundStyle(Theme.burntOrange)
    }
}

#Preview("Loading") {
    LoadingView(message: "Loading campus events…")
}

#Preview("Empty") {
    EmptyStateView(symbol: "calendar.badge.exclamationmark",
                   title: "Nothing here yet",
                   message: "No events match your filters. Try widening the date range.")
}
