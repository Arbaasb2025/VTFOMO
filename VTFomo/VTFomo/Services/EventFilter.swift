//
//  EventFilter.swift
//  VT FOMO
//
//  Turns the full list of events into the list a particular user should see.
//
//  PARADIGM NOTE — FUNCTIONAL.
//  Everything here is built from map / filter / reduce / sorted and closures.


import Foundation

/// The user's current filter choices. A struct so SwiftUI can diff it cheaply.
struct FilterOptions: Equatable {
    var tags: Set<EventTag> = []          // empty means "all tags"
    var hideEnded: Bool = true
    var onlyMyHall: Bool = false
    var onlySaved: Bool = false
    /// How many days ahead to show. 1 = today only.
    var dayWindow: Int = 7

    var isActive: Bool {
        !tags.isEmpty || onlyMyHall || onlySaved || dayWindow != 7
    }
}

enum EventFilter {

    static func visibleEvents(from all: [Event],
                              for user: AppUser,
                              options: FilterOptions,
                              now: Date = Date()) -> [Event] {

        let windowEnd = Calendar.current.date(byAdding: .day,
                                              value: options.dayWindow,
                                              to: now) ?? now

        // FUNCTIONAL: a chain of filters, each a closure over one condition.
        let savedIDs = Set(user.savedEvents.compactMap { $0.event?.id })

        return all
            .filter { !$0.isCancelled }
            .filter { $0.isVisible(to: user) }
            .filter { options.hideEnded ? $0.endTime > now : true }
            .filter { $0.startTime < windowEnd }
            .filter { options.tags.isEmpty ? true : options.tags.contains($0.tag) }
            .filter { options.onlyMyHall ? $0.isPriority(for: user) : true }
            .filter { options.onlySaved ? savedIDs.contains($0.id) : true }
            .sorted(by: makeSortComparator(for: user, now: now))
    }
    /// Returning a closure rather than a fixed sort keeps the rule in one place
    /// and lets the map and the list share it.
    static func makeSortComparator(for user: AppUser,
                                   now: Date = Date()) -> (Event, Event) -> Bool {
        return { a, b in
            let aPriority = a.isPriority(for: user)
            let bPriority = b.isPriority(for: user)
            if aPriority != bPriority { return aPriority }

            let aLive = a.timeState(now: now) == .live
            let bLive = b.timeState(now: now) == .live
            if aLive != bLive { return aLive }

            return a.startTime < b.startTime
        }
    }

    /// Groups events by calendar day for the list view's section headers.
    /// FUNCTIONAL: Dictionary(grouping:) plus a sorted map, no loops.
    static func groupedByDay(_ events: [Event]) -> [(day: Date, events: [Event])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startTime)
        }
        return groups
            .map { (day: $0.key, events: $0.value.sorted { $0.startTime < $1.startTime }) }
            .sorted { $0.day < $1.day }
    }

    /// Total number of saves across a set of events.
    /// FUNCTIONAL: reduce.
    static func totalSaves(_ events: [Event]) -> Int {
        events.reduce(0) { $0 + $1.saveCount }
    }

    /// How many events carry each tag, used for the filter chip badges.
    static func tagCounts(_ events: [Event]) -> [EventTag: Int] {
        events.reduce(into: [:]) { counts, event in
            counts[event.tag, default: 0] += 1
        }
    }
}
