//
//  VTFomoTests.swift
//  VT FOMO
//

import Testing
import Foundation
@testable import VTFomo

// MARK: - Validation

@Suite("Email validation")
struct EmailValidationTests {

    @Test("Accepts a normal VT address")
    func acceptsVTAddress() {
        #expect(Validation.isValidVTEmail("robertk@vt.edu"))
    }

    @Test("Accepts dots and hyphens in the net ID")
    func acceptsPunctuation() {
        #expect(Validation.isValidVTEmail("robert.k-smith@vt.edu"))
    }

    @Test("Is case insensitive")
    func caseInsensitive() {
        #expect(Validation.isValidVTEmail("RobertK@VT.EDU"))
    }

    @Test("Rejects other domains", arguments: [
        "robertk@gmail.com",
        "robertk@vtedu",
        "robertk@notvt.edu.com",
        "@vt.edu",
        ""
    ])
    func rejectsOthers(address: String) {
        #expect(!Validation.isValidVTEmail(address))
    }
}

@Suite("Password rules")
struct PasswordTests {

    @Test("Accepts a password meeting every rule")
    func acceptsStrong() {
        #expect(Validation.isValidPassword("Hokies2026"))
    }

    @Test("Reports exactly which rules failed")
    func reportsFailures() {
        let failures = Validation.failedPasswordRules(for: "short")
        #expect(failures.contains("At least 8 characters"))
        #expect(failures.contains("One uppercase letter"))
        #expect(failures.contains("One number"))
        #expect(!failures.contains("One lowercase letter"))
    }

    @Test("Rejects a long password with no digit")
    func rejectsNoDigit() {
        #expect(!Validation.isValidPassword("NoNumbersHere"))
    }
}

@Suite("Event time validation")
struct EventValidationTests {

    @Test("Rejects an empty title")
    func rejectsEmptyTitle() {
        let now = Date()
        let problem = Validation.eventProblem(title: "   ",
                                              start: now,
                                              end: now.addingTimeInterval(3600))
        #expect(problem != nil)
    }

    @Test("Rejects an end time before the start")
    func rejectsBackwardsTimes() {
        let now = Date()
        let problem = Validation.eventProblem(title: "Study Jam",
                                              start: now,
                                              end: now.addingTimeInterval(-600))
        #expect(problem != nil)
    }

    @Test("Accepts a sensible event")
    func acceptsValid() {
        let now = Date()
        let problem = Validation.eventProblem(title: "Study Jam",
                                              start: now,
                                              end: now.addingTimeInterval(7200))
        #expect(problem == nil)
    }
}

// MARK: - Visibility

@Suite("Event visibility")
struct VisibilityTests {

    /// Builds a throwaway user and hall. These are SwiftData models but they
    /// work as plain objects when never inserted into a context.
    private func makeUser(hallID: String, role: UserRole = .student) -> AppUser {
        let hall = Building(id: hallID, name: hallID.capitalized,
                            area: "Test", latitude: 0, longitude: 0)
        return AppUser(email: "\(hallID)@vt.edu",
                       displayName: "Test User",
                       passwordHash: "x",
                       role: role,
                       homeBuilding: hall)
    }

    private func makeEvent(visibility: EventVisibility,
                           halls: [String] = []) -> Event {
        Event(title: "Test Event",
              details: "",
              locationName: "Somewhere",
              latitude: 0, longitude: 0,
              startTime: Date(),
              endTime: Date().addingTimeInterval(3600),
              visibility: visibility,
              visibleBuildingIDs: halls)
    }

    @Test("Everyone can see a public event")
    func publicIsVisible() {
        let user = makeUser(hallID: "pritchard")
        #expect(makeEvent(visibility: .publicEvent).isVisible(to: user))
    }

    @Test("A resident can see their own hall's private event")
    func residentSeesOwnHall() {
        let user = makeUser(hallID: "pritchard")
        let event = makeEvent(visibility: .hallOnly, halls: ["pritchard"])
        #expect(event.isVisible(to: user))
    }

    @Test("A non-resident cannot see another hall's private event")
    func outsiderBlocked() {
        let user = makeUser(hallID: "lee")
        let event = makeEvent(visibility: .hallOnly, halls: ["pritchard"])
        #expect(!event.isVisible(to: user))
    }

    @Test("A user with no hall set cannot see any private event")
    func noHallBlocked() {
        let user = AppUser(email: "new@vt.edu", displayName: "New",
                           passwordHash: "x", role: .student)
        let event = makeEvent(visibility: .hallOnly, halls: ["pritchard"])
        #expect(!event.isVisible(to: user))
    }

    @Test("Own-hall events are marked as priority")
    func priorityFlag() {
        let user = makeUser(hallID: "pritchard")
        let mine = makeEvent(visibility: .hallOnly, halls: ["pritchard"])
        let theirs = makeEvent(visibility: .hallOnly, halls: ["lee"])
        #expect(mine.isPriority(for: user))
        #expect(!theirs.isPriority(for: user))
    }
}

// MARK: - Permissions

@Suite("Publishing permissions")
struct PermissionTests {

    @Test("A student cannot publish")
    func studentCannotPublish() {
        let user = AppUser(email: "s@vt.edu", displayName: "S",
                           passwordHash: "x", role: .student)
        #expect(!user.canPublishEvents())
    }

    @Test("An organizer can only restrict events to their own hall")
    func organizerScopedToOwnHall() {
        let pritchard = Building(id: "pritchard", name: "Pritchard",
                                 area: "Upper Quad", latitude: 0, longitude: 0)
        let lee = Building(id: "lee", name: "Lee",
                           area: "Upper Quad", latitude: 0, longitude: 0)
        let sl = AppUser(email: "sl@vt.edu", displayName: "SL",
                         passwordHash: "x", role: .organizer,
                         homeBuilding: pritchard)

        #expect(sl.canPublishToBuilding(pritchard))
        #expect(!sl.canPublishToBuilding(lee))
    }

    @Test("A coordinator covers every hall in their area but no others")
    func coordinatorScopedToArea() {
        let inArea = Building(id: "lee", name: "Lee",
                              area: "Upper Quad", latitude: 0, longitude: 0)
        let outOfArea = Building(id: "aj", name: "AJ",
                                 area: "Central", latitude: 0, longitude: 0)
        let coordinator = AppUser(email: "c@vt.edu", displayName: "C",
                                  passwordHash: "x", role: .areaCoordinator,
                                  managedArea: "Upper Quad")

        #expect(coordinator.canPublishToBuilding(inArea))
        #expect(!coordinator.canPublishToBuilding(outOfArea))
    }

    @Test("Nobody can grant a role at or above their own")
    func cannotPromoteAboveSelf() {
        let coordinator = AppUser(email: "c@vt.edu", displayName: "C",
                                  passwordHash: "x", role: .areaCoordinator,
                                  managedArea: "Upper Quad")
        #expect(coordinator.canGrantRole(.organizer, inArea: "Upper Quad"))
        #expect(!coordinator.canGrantRole(.areaCoordinator, inArea: "Upper Quad"))
        #expect(!coordinator.canGrantRole(.admin, inArea: "Upper Quad"))
        #expect(!coordinator.canGrantRole(.organizer, inArea: "Central"))
    }
}

// MARK: - Filtering

@Suite("Event filtering")
struct FilterTests {

    private func makeUser() -> AppUser {
        let hall = Building(id: "pritchard", name: "Pritchard",
                            area: "Upper Quad", latitude: 0, longitude: 0)
        return AppUser(email: "r@vt.edu", displayName: "R",
                       passwordHash: "x", role: .student, homeBuilding: hall)
    }

    private func makeEvent(title: String,
                           hoursFromNow: Double,
                           tag: EventTag = .social,
                           halls: [String] = []) -> Event {
        let start = Date().addingTimeInterval(hoursFromNow * 3600)
        return Event(title: title, details: "", locationName: "X",
                     latitude: 0, longitude: 0,
                     startTime: start,
                     endTime: start.addingTimeInterval(3600),
                     visibility: halls.isEmpty ? .publicEvent : .hallOnly,
                     tag: tag,
                     visibleBuildingIDs: halls)
    }

    @Test("Ended events are hidden by default")
    func hidesEnded() {
        let user = makeUser()
        let events = [makeEvent(title: "Past", hoursFromNow: -5),
                      makeEvent(title: "Future", hoursFromNow: 5)]
        let result = EventFilter.visibleEvents(from: events,
                                               for: user,
                                               options: FilterOptions())
        #expect(result.count == 1)
        #expect(result.first?.title == "Future")
    }

    @Test("Tag filter keeps only matching events")
    func filtersByTag() {
        let user = makeUser()
        let events = [makeEvent(title: "Pizza", hoursFromNow: 2, tag: .freeFood),
                      makeEvent(title: "Frisbee", hoursFromNow: 3, tag: .fitness)]
        var options = FilterOptions()
        options.tags = [.freeFood]

        let result = EventFilter.visibleEvents(from: events, for: user, options: options)
        #expect(result.map(\.title) == ["Pizza"])
    }

    @Test("Own-hall events sort above everything else")
    func prioritySortsFirst() {
        let user = makeUser()
        let events = [makeEvent(title: "Campus wide", hoursFromNow: 1),
                      makeEvent(title: "My hall", hoursFromNow: 6, halls: ["pritchard"])]
        let result = EventFilter.visibleEvents(from: events, for: user, options: FilterOptions())
        #expect(result.first?.title == "My hall")
    }

    @Test("Another hall's private event never appears")
    func foreignHallExcluded() {
        let user = makeUser()
        let events = [makeEvent(title: "Lee only", hoursFromNow: 2, halls: ["lee"])]
        let result = EventFilter.visibleEvents(from: events, for: user, options: FilterOptions())
        #expect(result.isEmpty)
    }

    @Test("Grouping by day produces days in order")
    func groupsByDay() {
        let events = [makeEvent(title: "Later", hoursFromNow: 50),
                      makeEvent(title: "Sooner", hoursFromNow: 2)]
        let groups = EventFilter.groupedByDay(events)
        #expect(groups.count == 2)
        #expect(groups[0].day < groups[1].day)
    }
}
