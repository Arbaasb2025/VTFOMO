//
//  EventListScreen.swift
//  VT FOMO
//
//  Chronological list of events, grouped by day.
//
//  On iPhone this is a tab of its own and pushes a detail view.
//  On iPad it is the sidebar of the NavigationSplitView and drives the map
//  selection instead of pushing - which is why `selection` is optional.
//

import SwiftUI
import SwiftData

struct EventListScreen: View {

    @Environment(\.modelContext) private var context

    let user: AppUser
    @Binding var options: FilterOptions
    /// Non-nil only in the iPad layout.
    var selection: Binding<Event?>? = nil

    @Query private var allEvents: [Event]
    @State private var searchText = ""

    private var events: [Event] {
        let base = EventFilter.visibleEvents(from: allEvents, for: user, options: options)
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.locationName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var days: [(day: Date, events: [Event])] {
        EventFilter.groupedByDay(events)
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(options: $options, counts: EventFilter.tagCounts(events))

            if events.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.exclamationmark",
                    title: "Nothing coming up",
                    message: options.isActive
                        ? "No events match your filters right now."
                        : "There are no events scheduled in the next week.",
                    actionTitle: options.isActive ? "Clear filters" : nil,
                    action: options.isActive ? { options = FilterOptions() } : nil
                )
            } else {
                list
            }
        }
        .background(Theme.background)
        .navigationTitle("Events")
        .searchable(text: $searchText, prompt: "Search events")
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section(header: Text(sectionTitle(for: group.day))) {
                    ForEach(group.events) { event in
                        rowContent(for: event)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// On iPad the row sets the shared selection; on iPhone it pushes.
    @ViewBuilder
    private func rowContent(for event: Event) -> some View {
        if let selection {
            Button {
                selection.wrappedValue = event
            } label: {
                EventRow(event: event, isPriority: event.isPriority(for: user))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                EventDetailView(event: event, user: user)
            } label: {
                EventRow(event: event, isPriority: event.isPriority(for: user))
            }
        }
    }

    /// "Today" / "Tomorrow" / "Fri, Sep 18"
    private func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return Theme.dayFormatter.string(from: day)
    }
}
