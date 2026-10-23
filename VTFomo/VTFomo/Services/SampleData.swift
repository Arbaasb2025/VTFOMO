//
//  SampleData.swift
//  VT FOMO
//
//  Seeds the database the first time the app launches so there is something
//  to look at immediately.
//
//  Contents: 6 residence halls, 3 organizations, 9 users (4 organizers,
//  4 students, 1 area coordinator) and a spread of events across the next
//  week - some already ended, some live, some upcoming - so every pin colour
//  and filter state can be demonstrated.
//
//  NOTE ON COORDINATES: the latitude/longitude values below are approximate
//  positions on the Blacksburg campus. Verify them against the real campus map
//  before the final submission.
//

import Foundation
import SwiftData

enum SampleData {

    /// Demo password for every seeded account. Meets the rules in Validation.
    static let demoPassword = "Hokies2026"

    /// Inserts the sample data if the store is empty. Safe to call every launch.
    static func seedIfNeeded(context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Building>())
        guard existing?.isEmpty ?? true else { return }

        let buildings = makeBuildings()
        buildings.forEach { context.insert($0) }

        let orgs = makeOrganizations()
        orgs.forEach { context.insert($0) }

        let users = makeUsers(buildings: buildings, organizations: orgs)
        users.forEach { context.insert($0) }

        let events = makeEvents(buildings: buildings, organizations: orgs, users: users)
        events.forEach { context.insert($0) }

        // Give a couple of events some saves so the organizer dashboard has
        // numbers in it on first run.
        let students = users.filter { $0.role == .student }
        for (index, event) in events.prefix(4).enumerated() {
            for student in students.prefix(index + 1) {
                context.insert(SavedEvent(user: student, event: event))
            }
        }

        try? context.save()
    }

    // MARK: - Buildings

    private static func makeBuildings() -> [Building] {
        [
            Building(id: "pritchard",  name: "Pritchard Hall",
                     area: "Upper Quad", latitude: 37.2214, longitude: -80.4238),
            Building(id: "lee",        name: "Lee Hall",
                     area: "Upper Quad", latitude: 37.2220, longitude: -80.4250),
            Building(id: "oshag",      name: "O'Shaughnessy Hall",
                     area: "Upper Quad", latitude: 37.2211, longitude: -80.4224),
            Building(id: "aj",         name: "Ambler Johnston Hall",
                     area: "Central",    latitude: 37.2200, longitude: -80.4247),
            Building(id: "slusher",    name: "Slusher Hall",
                     area: "Central",    latitude: 37.2213, longitude: -80.4265),
            Building(id: "newhall",    name: "New Hall West",
                     area: "East",       latitude: 37.2262, longitude: -80.4162)
        ]
    }

    // MARK: - Organizations

    private static func makeOrganizations() -> [Organization] {
        [
            Organization(id: "acm", name: "Association for Computing Machinery",
                         abbreviation: "ACM",
                         summary: "Student chapter for computing and software."),
            Organization(id: "recsports", name: "Rec Sports",
                         abbreviation: "Rec",
                         summary: "Intramurals, fitness classes, and open gym."),
            Organization(id: "sga", name: "Student Government Association",
                         abbreviation: "SGA",
                         summary: "Student representation and campus-wide programming.")
        ]
    }

    // MARK: - Users

    private static func makeUsers(buildings: [Building],
                                  organizations: [Organization]) -> [AppUser] {

        // Small helper so we can look a building up by id without a loop.
        let byID = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) })
        let orgByID = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0) })
        let hash = AuthService.hash(demoPassword)

        return [
            // --- Organizers (4) ---
            AppUser(email: "emmac@vt.edu", displayName: "Emma Carter",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: byID["pritchard"]),

            AppUser(email: "jdavis@vt.edu", displayName: "Jordan Davis",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: byID["aj"]),

            AppUser(email: "priyan@vt.edu", displayName: "Priya Nair",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: byID["newhall"],
                    organization: orgByID["acm"]),

            AppUser(email: "marcusw@vt.edu", displayName: "Marcus Webb",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: byID["lee"],
                    organization: orgByID["recsports"]),

            // --- Students (4) ---
            AppUser(email: "robertk@vt.edu", displayName: "Robert Kim",
                    passwordHash: hash, role: .student,
                    homeBuilding: byID["pritchard"]),

            AppUser(email: "sofiar@vt.edu", displayName: "Sofia Ramirez",
                    passwordHash: hash, role: .student,
                    homeBuilding: byID["aj"]),

            AppUser(email: "tylerb@vt.edu", displayName: "Tyler Brooks",
                    passwordHash: hash, role: .student,
                    homeBuilding: byID["lee"]),

            AppUser(email: "aishas@vt.edu", displayName: "Aisha Simmons",
                    passwordHash: hash, role: .student,
                    homeBuilding: byID["newhall"]),

            // --- Area Coordinator (1) ---
            AppUser(email: "dmorales@vt.edu", displayName: "Dana Morales",
                    passwordHash: hash, role: .areaCoordinator,
                    managedArea: "Upper Quad",
                    homeBuilding: byID["pritchard"])
        ]
    }

    // MARK: - Events

    private static func makeEvents(buildings: [Building],
                                   organizations: [Organization],
                                   users: [AppUser]) -> [Event] {

        let cal = Calendar.current
        let now = Date()

        /// Builds a date `days` from now at a given hour.
        func date(daysFromNow days: Int, hour: Int, minute: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: days, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        let orgByID = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0) })
        let userByEmail = Dictionary(uniqueKeysWithValues: users.map { ($0.email, $0) })

        return [
            // Happening right now - shows the green "live" pin.
            Event(title: "Pritchard Pizza & Board Games",
                  details: "Free pizza in the lounge, plus Catan, Uno, and whatever else people bring. Drop in any time.",
                  locationName: "Pritchard Hall Main Lounge",
                  latitude: 37.2214, longitude: -80.4238,
                  startTime: now.addingTimeInterval(-1800),
                  endTime: now.addingTimeInterval(3600),
                  visibility: .hallOnly, tag: .freeFood,
                  visibleBuildingIDs: ["pritchard"],
                  organizer: userByEmail["emmac@vt.edu"]),

            // Starts within the hour - orange pin.
            Event(title: "Drillfield Sunset Frisbee",
                  details: "Casual pickup ultimate. No experience needed, we will explain the rules.",
                  locationName: "Drillfield",
                  latitude: 37.2277, longitude: -80.4229,
                  startTime: now.addingTimeInterval(2400),
                  endTime: now.addingTimeInterval(9000),
                  visibility: .publicEvent, tag: .fitness,
                  organizer: userByEmail["marcusw@vt.edu"],
                  organization: orgByID["recsports"]),

            Event(title: "ACM Resume Workshop",
                  details: "Bring a laptop and a draft. Recruiters from three companies will do live reviews for the last half hour.",
                  locationName: "Torgersen Hall 2150",
                  latitude: 37.2296, longitude: -80.4187,
                  startTime: date(daysFromNow: 1, hour: 18),
                  endTime: date(daysFromNow: 1, hour: 20),
                  visibility: .publicEvent, tag: .career,
                  organizer: userByEmail["priyan@vt.edu"],
                  organization: orgByID["acm"]),

            Event(title: "AJ Late Night Breakfast",
                  details: "Pancakes and hash browns at midnight before midterms. Residents only.",
                  locationName: "Ambler Johnston Dining",
                  latitude: 37.2200, longitude: -80.4247,
                  startTime: date(daysFromNow: 2, hour: 23),
                  endTime: date(daysFromNow: 3, hour: 1),
                  visibility: .hallOnly, tag: .freeFood,
                  visibleBuildingIDs: ["aj"],
                  organizer: userByEmail["jdavis@vt.edu"]),

            Event(title: "Upper Quad Study Jam",
                  details: "Quiet study with free coffee and snacks. Open to all three Upper Quad halls.",
                  locationName: "Lee Hall Study Room",
                  latitude: 37.2220, longitude: -80.4250,
                  startTime: date(daysFromNow: 2, hour: 19),
                  endTime: date(daysFromNow: 2, hour: 22),
                  visibility: .hallOnly, tag: .academic,
                  visibleBuildingIDs: ["pritchard", "lee", "oshag"],
                  organizer: userByEmail["emmac@vt.edu"]),

            Event(title: "Free Yoga on the Lawn",
                  details: "Beginner friendly. Mats provided, first come first served.",
                  locationName: "War Memorial Lawn",
                  latitude: 37.2251, longitude: -80.4243,
                  startTime: date(daysFromNow: 3, hour: 9),
                  endTime: date(daysFromNow: 3, hour: 10),
                  visibility: .publicEvent, tag: .wellness,
                  organizer: userByEmail["marcusw@vt.edu"],
                  organization: orgByID["recsports"]),

            Event(title: "New Hall West Ice Cream Social",
                  details: "Meet your floor. Toppings bar and a photo booth.",
                  locationName: "New Hall West Lobby",
                  latitude: 37.2262, longitude: -80.4162,
                  startTime: date(daysFromNow: 4, hour: 20),
                  endTime: date(daysFromNow: 4, hour: 22),
                  visibility: .hallOnly, tag: .social,
                  visibleBuildingIDs: ["newhall"],
                  organizer: userByEmail["priyan@vt.edu"]),

            Event(title: "SGA Town Hall",
                  details: "Bring questions about dining, parking, and housing. Administrators will be present.",
                  locationName: "Squires Student Center",
                  latitude: 37.2294, longitude: -80.4160,
                  startTime: date(daysFromNow: 5, hour: 17),
                  endTime: date(daysFromNow: 5, hour: 18, minute: 30),
                  visibility: .publicEvent, tag: .academic,
                  organizer: userByEmail["emmac@vt.edu"],
                  organization: orgByID["sga"]),

            // Already ended - shows the greyed out "past" state.
            Event(title: "Welcome Week Cookout",
                  details: "Burgers, music, and lawn games to kick off the semester.",
                  locationName: "Drillfield",
                  latitude: 37.2280, longitude: -80.4222,
                  startTime: date(daysFromNow: -2, hour: 17),
                  endTime: date(daysFromNow: -2, hour: 20),
                  visibility: .publicEvent, tag: .social,
                  organizer: userByEmail["jdavis@vt.edu"])
        ]
    }
}
