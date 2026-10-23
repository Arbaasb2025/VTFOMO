//
//  SavedEventsScreen.swift
//  VT FOMO
//
//  Everything the user has saved, split into what is still coming up and what
//  has already happened.
//

import SwiftUI
import SwiftData

struct SavedEventsScreen: View {

    @Environment(\.modelContext) private var context
    let user: AppUser

    /// FUNCTIONAL: pull the events out of the join records, drop any that were
    /// deleted, and split them by whether they have ended.
    private var saved: [Event] {
        user.savedEvents
            .compactMap(\.event)
            .filter { !$0.isCancelled }
            .sorted { $0.startTime < $1.startTime }
    }

    private var upcoming: [Event] {
        saved.filter { $0.endTime > Date() }
    }

    private var past: [Event] {
        saved.filter { $0.endTime <= Date() }.reversed()
    }

    var body: some View {
        Group {
            if saved.isEmpty {
                EmptyStateView(
                    symbol: "bookmark",
                    title: "Nothing saved yet",
                    message: "Tap a pin on the map and save an event to get a reminder before it starts."
                )
            } else {
                List {
                    if !upcoming.isEmpty {
                        Section("Coming up") {
                            ForEach(upcoming) { event in
                                NavigationLink {
                                    EventDetailView(event: event, user: user)
                                } label: {
                                    EventRow(event: event,
                                             isPriority: event.isPriority(for: user))
                                }
                            }
                            .onDelete { unsave(from: upcoming, at: $0) }
                        }
                    }
                    if !past.isEmpty {
                        Section("Already happened") {
                            ForEach(past) { event in
                                NavigationLink {
                                    EventDetailView(event: event, user: user)
                                } label: {
                                    EventRow(event: event)
                                }
                            }
                            .onDelete { unsave(from: past, at: $0) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.background)
        .navigationTitle("Saved")
    }

    /// Swipe to remove a saved event, cancelling its reminder too.
    private func unsave(from list: [Event], at offsets: IndexSet) {
        for index in offsets {
            let event = list[index]
            guard let record = user.savedEvents.first(where: { $0.event?.id == event.id })
            else { continue }
            if let id = record.notificationID {
                NotificationService.cancelReminder(id: id)
            }
            context.delete(record)
        }
        try? context.save()
    }
}
