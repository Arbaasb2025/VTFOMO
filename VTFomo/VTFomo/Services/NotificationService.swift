//
//  NotificationService.swift
//  VT FOMO
//
//  Schedules a local notification before a saved event starts.
//
//  These are LOCAL notifications, not push. Local needs no server, no APNs
//  certificate, and works in the simulator, which is why it was chosen for a
//  one-semester project. The trade-off is that reminders only fire for events
//  the user has already saved on this device.
//

import Foundation
import UserNotifications

enum NotificationService {

    /// Asks for permission. Safe to call more than once; iOS only prompts once.
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedules a reminder and returns its identifier so it can be cancelled.
    /// Returns nil if the reminder time has already passed.
    @discardableResult
    static func scheduleReminder(for event: Event, minutesBefore: Int) async -> String? {
        let fireDate = event.startTime.addingTimeInterval(-Double(minutesBefore) * 60)
        guard fireDate > Date() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Starts in \(minutesBefore) minutes at \(event.locationName)."
        content.sound = .default
        content.userInfo = ["eventID": event.id]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "reminder-\(event.id)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            return id
        } catch {
            return nil
        }
    }

    /// Called when the user unsaves an event or the organizer cancels it.
    static func cancelReminder(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
