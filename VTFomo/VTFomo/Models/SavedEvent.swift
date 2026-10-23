//
//  SavedEvent.swift
//  VT FOMO
//
//  Join model linking a user to an event they saved.
//
//  We could have modelled this as a direct many-to-many between AppUser and
//  Event. A separate join model is used instead for two reasons:
//    1. SwiftData many-to-many relationships are fiddly to keep in sync.
//    2. It gives us somewhere to hang extra data - when they saved it, and
//       whether they want a reminder - which a bare link could not hold.
//

import Foundation
import SwiftData

@Model
final class SavedEvent {

    @Attribute(.unique) var id: String
    var savedAt: Date
    /// Minutes before the start time to fire the local notification.
    var reminderMinutesBefore: Int
    /// Identifier of the scheduled UNNotificationRequest, so we can cancel it
    /// if the user unsaves the event or the organizer cancels it.
    var notificationID: String?

    var user: AppUser?
    var event: Event?

    init(id: String = UUID().uuidString,
         user: AppUser?,
         event: Event?,
         reminderMinutesBefore: Int = 30) {
        self.id = id
        self.user = user
        self.event = event
        self.reminderMinutesBefore = reminderMinutesBefore
        self.savedAt = Date()
    }
}
