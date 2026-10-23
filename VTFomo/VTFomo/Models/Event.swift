//
//  Event.swift
//  VT FOMO
//
//  The core entity. An event has a place, a time window, a visibility rule,
//  and an organizer.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Event {

    // MARK: - Stored properties

    @Attribute(.unique) var id: String
    var title: String
    var details: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var startTime: Date
    var endTime: Date
    /// EventVisibility.rawValue
    var visibilityRaw: String
    /// EventTag.rawValue
    var tagRaw: String
    /// Building IDs allowed to see this event when visibility is .hallOnly.
    ///
    /// Stored as a plain [String] rather than a many-to-many relationship.
    /// A relationship would be tidier on paper, but SwiftData many-to-many
    /// links are awkward to filter inside #Predicate, and this list is short
    /// and never needs its own queries.
    var visibleBuildingIDs: [String]
    /// Names of images in Assets.xcassets, or file names in the documents
    /// directory for photos the organizer picked.
    var photoNames: [String]
    var isCancelled: Bool
    var createdAt: Date

    // MARK: - Relationships

    var organizer: AppUser?
    var organization: Organization?

    @Relationship(deleteRule: .cascade, inverse: \SavedEvent.event)
    var savedBy: [SavedEvent] = []

    // MARK: - Init

    init(id: String = UUID().uuidString,
         title: String,
         details: String,
         locationName: String,
         latitude: Double,
         longitude: Double,
         startTime: Date,
         endTime: Date,
         visibility: EventVisibility = .publicEvent,
         tag: EventTag = .social,
         visibleBuildingIDs: [String] = [],
         photoNames: [String] = [],
         organizer: AppUser? = nil,
         organization: Organization? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.startTime = startTime
        self.endTime = endTime
        self.visibilityRaw = visibility.rawValue
        self.tagRaw = tag.rawValue
        self.visibleBuildingIDs = visibleBuildingIDs
        self.photoNames = photoNames
        self.organizer = organizer
        self.organization = organization
        self.isCancelled = false
        self.createdAt = Date()
    }

    // MARK: - Computed

    var visibility: EventVisibility {
        get { EventVisibility(rawValue: visibilityRaw) ?? .publicEvent }
        set { visibilityRaw = newValue.rawValue }
    }

    var tag: EventTag {
        get { EventTag(rawValue: tagRaw) ?? .social }
        set { tagRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var saveCount: Int { savedBy.count }

    /// Where this event sits relative to right now.
    func timeState(now: Date = Date()) -> EventTimeState {
        if now > endTime { return .past }
        if now >= startTime { return .live }
        if startTime.timeIntervalSince(now) <= 3600 { return .soon }
        return .upcoming
    }

    /// Name shown as the host: the club if there is one, otherwise the person.
    var hostName: String {
        organization?.name ?? organizer?.displayName ?? "Virginia Tech"
    }

    // MARK: - Visibility

    /// Is this event visible to `user`?
    ///
    /// IMPORTANT: this is a CLIENT-SIDE check. It shapes the UI and nothing
    /// more. In a deployed version the same rule has to run on the server so
    /// hall-only events are never sent to a device that shouldn't have them.
    /// Filtering only here would mean the data was already downloaded.
    func isVisible(to user: AppUser) -> Bool {
        if user.role == .admin { return true }
        if organizer?.id == user.id { return true }

        switch visibility {
        case .publicEvent:
            return true
        case .hallOnly:
            guard let hallID = user.homeBuilding?.id else { return false }
            return visibleBuildingIDs.contains(hallID)
        }
    }

    /// True if this event belongs to the user's own hall, which is what makes
    /// it float to the top of the list and get a highlighted pin.
    func isPriority(for user: AppUser) -> Bool {
        guard let hallID = user.homeBuilding?.id else { return false }
        return visibleBuildingIDs.contains(hallID)
    }
}
