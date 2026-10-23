//
//  Enums.swift
//  VT FOMO
//
//  Shared enumerations used across the data model.
//  These are stored in SwiftData as raw String values (see the `*Raw`
//  properties on the @Model classes) because raw strings are the most
//  reliable type to use inside SwiftData #Predicate expressions.
//

import Foundation
import SwiftUI

/// What a user is allowed to do in the app.
/// Roles are ordered from least to most authority; see `rank`.
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case student            // can browse, save, and get reminders
    case organizer          // RA / SL / club officer - can publish events
    case areaCoordinator    // housing staff - can approve organizers in their area
    case admin              // system administrator

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student:         return "Student"
        case .organizer:       return "Event Organizer"
        case .areaCoordinator: return "Area Coordinator"
        case .admin:           return "Administrator"
        }
    }

    /// Higher rank means more authority. Used to stop a coordinator from
    /// promoting somebody to a role at or above their own.
    var rank: Int {
        switch self {
        case .student:         return 0
        case .organizer:       return 1
        case .areaCoordinator: return 2
        case .admin:           return 3
        }
    }

    /// True if this role is allowed to publish events.
    var canPublishEvents: Bool { rank >= UserRole.organizer.rank }
}

/// Who is allowed to see an event.
enum EventVisibility: String, Codable, CaseIterable, Identifiable {
    case publicEvent = "public"   // everyone on campus
    case hallOnly    = "hallOnly" // only residents of specific halls

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .publicEvent: return "Public"
        case .hallOnly:    return "Specific Halls"
        }
    }
}

/// Category tag used for filtering on the map.
enum EventTag: String, Codable, CaseIterable, Identifiable {
    case freeFood
    case social
    case academic
    case career
    case fitness
    case wellness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freeFood: return "Free Food"
        case .social:   return "Social"
        case .academic: return "Academic"
        case .career:   return "Career"
        case .fitness:  return "Fitness"
        case .wellness: return "Wellness"
        }
    }

    var symbolName: String {
        switch self {
        case .freeFood: return "fork.knife"
        case .social:   return "person.2.fill"
        case .academic: return "book.fill"
        case .career:   return "briefcase.fill"
        case .fitness:  return "figure.run"
        case .wellness: return "heart.fill"
        }
    }
}

/// Where an event sits relative to right now. Drives the pin colour on the map.
enum EventTimeState {
    case upcoming
    case soon      // starts within the next hour
    case live      // happening right now
    case past

    var color: Color {
        switch self {
        case .upcoming: return Theme.maroon
        case .soon:     return Theme.orange
        case .live:     return Theme.green
        case .past:     return Theme.gray
        }
    }

    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .soon:     return "Starting soon"
        case .live:     return "Happening now"
        case .past:     return "Ended"
        }
    }
}
