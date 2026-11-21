import Foundation
import SwiftData

// Creates the initial campus data and replenishes public demo events
// when an existing installation has nothing upcoming to show.
enum SampleData {

    static let demoPassword = "Hokies2026"

    static func seedIfNeeded(context: ModelContext) {
        do {
            let existingBuildings = try context.fetch(FetchDescriptor<Building>())

            if existingBuildings.isEmpty {
                let buildings = makeBuildings()
                buildings.forEach { context.insert($0) }

                let organizations = makeOrganizations()
                organizations.forEach { context.insert($0) }

                let users = makeUsers(
                    buildings: buildings,
                    organizations: organizations
                )
                users.forEach { context.insert($0) }

                let events = makeEvents(organizations: organizations, users: users)
                events.forEach { context.insert($0) }

                let students = users.filter { $0.role == .student }
                for (index, event) in events.prefix(4).enumerated() {
                    for student in students.prefix(index + 1) {
                        context.insert(SavedEvent(user: student, event: event))
                    }
                }
            } else {
                try addDemoScheduleIfNeeded(context: context)
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            context.rollback()
            print("Could not prepare VT FOMO sample data: \(error)")
        }
    }

    // MARK: - Public demo events for returning installations

    private static func addDemoScheduleIfNeeded(context: ModelContext) throws {
        let now = Date()
        let calendar = Calendar.current
        guard let horizon = calendar.date(byAdding: .day, value: 7, to: now) else {
            return
        }

        let events = try context.fetch(FetchDescriptor<Event>())
        let hasPublicEvent = events.contains { event in
            event.visibility == .publicEvent &&
            !event.isCancelled &&
            event.endTime > now &&
            event.startTime < horizon
        }
        guard !hasPublicEvent else { return }

        let day = Int(calendar.startOfDay(for: now).timeIntervalSince1970)
        let existingIDs = Set(events.map { $0.id })

        func addSession(
            key: String,
            title: String,
            details: String,
            location: String,
            latitude: Double,
            longitude: Double,
            tag: EventTag,
            start: Date
        ) {
            let id = "demo-session-\(day)-\(key)"
            guard !existingIDs.contains(id) else { return }

            context.insert(Event(
                id: id,
                title: title,
                details: details,
                locationName: location,
                latitude: latitude,
                longitude: longitude,
                startTime: start,
                endTime: start.addingTimeInterval(3600),
                visibility: .publicEvent,
                tag: tag
            ))
        }

        addSession(
            key: "games",
            title: "Squires Board Game Meetup",
            details: "Drop in for a round of Uno or Catan. Beginners welcome.",
            location: "Squires Student Center",
            latitude: 37.2294,
            longitude: -80.4160,
            tag: .social,
            start: now.addingTimeInterval(-15 * 60)
        )

        addSession(
            key: "frisbee",
            title: "Drillfield Pickup Frisbee",
            details: "Join a casual pickup game on the Drillfield. Discs provided.",
            location: "Drillfield",
            latitude: 37.2277,
            longitude: -80.4229,
            tag: .fitness,
            start: now.addingTimeInterval(45 * 60)
        )

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            addSession(
                key: "study",
                title: "Torgersen Study Social",
                details: "Bring a class problem and find a study partner.",
                location: "Torgersen Hall",
                latitude: 37.2296,
                longitude: -80.4187,
                tag: .academic,
                start: tomorrow
            )
        }
    }

    // MARK: - Buildings

    private static func makeBuildings() -> [Building] {
        [
            Building(id: "pritchard", name: "Pritchard Hall",
                     area: "Upper Quad", latitude: 37.2214, longitude: -80.4238),
            Building(id: "lee", name: "Lee Hall",
                     area: "Upper Quad", latitude: 37.2220, longitude: -80.4250),
            Building(id: "oshag", name: "O'Shaughnessy Hall",
                     area: "Upper Quad", latitude: 37.2211, longitude: -80.4224),
            Building(id: "aj", name: "Ambler Johnston Hall",
                     area: "Central", latitude: 37.2200, longitude: -80.4247),
            Building(id: "slusher", name: "Slusher Hall",
                     area: "Central", latitude: 37.2213, longitude: -80.4265),
            Building(id: "newhall", name: "New Hall West",
                     area: "East", latitude: 37.2262, longitude: -80.4162)
        ]
    }

    // MARK: - Organizations

    private static func makeOrganizations() -> [Organization] {
        [
            Organization(
                id: "acm",
                name: "Association for Computing Machinery",
                abbreviation: "ACM",
                summary: "Student chapter for computing and software."
            ),
            Organization(
                id: "recsports",
                name: "Rec Sports",
                abbreviation: "Rec",
                summary: "Intramurals, fitness classes, and open gym."
            ),
            Organization(
                id: "sga",
                name: "Student Government Association",
                abbreviation: "SGA",
                summary: "Student representation and campus-wide programming."
            )
        ]
    }

    // MARK: - Users

    private static func makeUsers(
        buildings: [Building],
        organizations: [Organization]
    ) -> [AppUser] {
        let halls = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) })
        let clubs = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0) })
        let hash = AuthService.hash(demoPassword)

        return [
            AppUser(email: "emmac@vt.edu", displayName: "Emma Carter",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: halls["pritchard"]),
            AppUser(email: "jdavis@vt.edu", displayName: "Jordan Davis",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: halls["aj"]),
            AppUser(email: "priyan@vt.edu", displayName: "Priya Nair",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: halls["newhall"], organization: clubs["acm"]),
            AppUser(email: "marcusw@vt.edu", displayName: "Marcus Webb",
                    passwordHash: hash, role: .organizer,
                    homeBuilding: halls["lee"], organization: clubs["recsports"]),
            AppUser(email: "robertk@vt.edu", displayName: "Robert Kim",
                    passwordHash: hash, role: .student,
                    homeBuilding: halls["pritchard"]),
            AppUser(email: "sofiar@vt.edu", displayName: "Sofia Ramirez",
                    passwordHash: hash, role: .student,
                    homeBuilding: halls["aj"]),
            AppUser(email: "tylerb@vt.edu", displayName: "Tyler Brooks",
                    passwordHash: hash, role: .student,
                    homeBuilding: halls["lee"]),
            AppUser(email: "aishas@vt.edu", displayName: "Aisha Simmons",
                    passwordHash: hash, role: .student,
                    homeBuilding: halls["newhall"]),
            AppUser(email: "dmorales@vt.edu", displayName: "Dana Morales",
                    passwordHash: hash, role: .areaCoordinator,
                    managedArea: "Upper Quad", homeBuilding: halls["pritchard"])
        ]
    }

    // MARK: - Initial campus events

    private static func makeEvents(
        organizations: [Organization],
        users: [AppUser]
    ) -> [Event] {
        let calendar = Calendar.current
        let now = Date()
        let clubs = Dictionary(uniqueKeysWithValues: organizations.map { ($0.id, $0) })
        let people = Dictionary(uniqueKeysWithValues: users.map { ($0.email, $0) })

        func date(days: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) ?? day
        }

        return [
            Event(
                title: "Pritchard Pizza & Board Games",
                details: "Free pizza in the lounge, plus Catan, Uno, and whatever else people bring. Drop in any time.",
                locationName: "Pritchard Hall Main Lounge",
                latitude: 37.2214, longitude: -80.4238,
                startTime: now.addingTimeInterval(-1800),
                endTime: now.addingTimeInterval(3600),
                visibility: .hallOnly, tag: .freeFood,
                visibleBuildingIDs: ["pritchard"],
                organizer: people["emmac@vt.edu"]
            ),
            Event(
                title: "Drillfield Sunset Frisbee",
                details: "Casual pickup ultimate. No experience needed, we will explain the rules.",
                locationName: "Drillfield",
                latitude: 37.2277, longitude: -80.4229,
                startTime: now.addingTimeInterval(2400),
                endTime: now.addingTimeInterval(9000),
                visibility: .publicEvent, tag: .fitness,
                organizer: people["marcusw@vt.edu"],
                organization: clubs["recsports"]
            ),
            Event(
                title: "ACM Resume Workshop",
                details: "Bring a laptop and a draft. Recruiters from three companies will do live reviews for the last half hour.",
                locationName: "Torgersen Hall 2150",
                latitude: 37.2296, longitude: -80.4187,
                startTime: date(days: 1, hour: 18),
                endTime: date(days: 1, hour: 20),
                visibility: .publicEvent, tag: .career,
                organizer: people["priyan@vt.edu"],
                organization: clubs["acm"]
            ),
            Event(
                title: "AJ Late Night Breakfast",
                details: "Pancakes and hash browns at midnight before midterms. Residents only.",
                locationName: "Ambler Johnston Dining",
                latitude: 37.2200, longitude: -80.4247,
                startTime: date(days: 2, hour: 23),
                endTime: date(days: 3, hour: 1),
                visibility: .hallOnly, tag: .freeFood,
                visibleBuildingIDs: ["aj"],
                organizer: people["jdavis@vt.edu"]
            ),
            Event(
                title: "Upper Quad Study Jam",
                details: "Quiet study with free coffee and snacks. Open to all three Upper Quad halls.",
                locationName: "Lee Hall Study Room",
                latitude: 37.2220, longitude: -80.4250,
                startTime: date(days: 2, hour: 19),
                endTime: date(days: 2, hour: 22),
                visibility: .hallOnly, tag: .academic,
                visibleBuildingIDs: ["pritchard", "lee", "oshag"],
                organizer: people["emmac@vt.edu"]
            ),
            Event(
                title: "Free Yoga on the Lawn",
                details: "Beginner friendly. Mats provided, first come first served.",
                locationName: "War Memorial Lawn",
                latitude: 37.2251, longitude: -80.4243,
                startTime: date(days: 3, hour: 9),
                endTime: date(days: 3, hour: 10),
                visibility: .publicEvent, tag: .wellness,
                organizer: people["marcusw@vt.edu"],
                organization: clubs["recsports"]
            ),
            Event(
                title: "New Hall West Ice Cream Social",
                details: "Meet your floor. Toppings bar and a photo booth.",
                locationName: "New Hall West Lobby",
                latitude: 37.2262, longitude: -80.4162,
                startTime: date(days: 4, hour: 20),
                endTime: date(days: 4, hour: 22),
                visibility: .hallOnly, tag: .social,
                visibleBuildingIDs: ["newhall"],
                organizer: people["priyan@vt.edu"]
            ),
            Event(
                title: "SGA Town Hall",
                details: "Bring questions about dining, parking, and housing. Administrators will be present.",
                locationName: "Squires Student Center",
                latitude: 37.2294, longitude: -80.4160,
                startTime: date(days: 5, hour: 17),
                endTime: date(days: 5, hour: 18, minute: 30),
                visibility: .publicEvent, tag: .academic,
                organizer: people["emmac@vt.edu"],
                organization: clubs["sga"]
            ),
            Event(
                title: "Welcome Week Cookout",
                details: "Burgers, music, and lawn games to kick off the semester.",
                locationName: "Drillfield",
                latitude: 37.2280, longitude: -80.4222,
                startTime: date(days: -2, hour: 17),
                endTime: date(days: -2, hour: 20),
                visibility: .publicEvent, tag: .social,
                organizer: people["jdavis@vt.edu"]
            )
        ]
    }
}

#if DEBUG
extension SampleData {

    // Add missing demo accounts while preserving each existing account's role
    // and approval state between launches.
    static func ensureRoleDemoAccounts(context: ModelContext) {
        do {
            let users = try context.fetch(FetchDescriptor<AppUser>())
            let buildings = try context.fetch(FetchDescriptor<Building>())
            guard let hall = buildings.first(where: { $0.id == "pritchard" }) else {
                return
            }

            let specifications: [(String, String, UserRole, OrganizerKind?)] = [
                ("arbaasb@gmail.com", "Arbaas · Demo Admin", .admin, nil),
                ("cord@vt.edu", "Demo Area Coordinator", .areaCoordinator, nil),
                ("org@vt.edu", "Demo Authorized Organizer", .student, .authorizedOrganizer),
                ("sl@vt.edu", "Demo Student Leader", .student, .studentLeader),
                ("stu@vt.edu", "Demo Student", .student, nil)
            ]

            for (email, name, role, kind) in specifications {
                guard !users.contains(where: { $0.email.lowercased() == email }) else {
                    continue
                }

                let user = AppUser(
                    email: email,
                    displayName: name,
                    passwordHash: AuthService.hash(demoPassword),
                    role: role,
                    managedArea: role == .areaCoordinator ? "Upper Quad" : nil,
                    homeBuilding: hall
                )

                if let kind {
                    user.requestedOrganizerHallID = hall.id
                    user.requestedOrganizerKindRaw = kind.rawValue
                    user.requestedAffiliation = kind == .authorizedOrganizer
                        ? "Demo university team"
                        : nil
                }

                context.insert(user)
            }

            try context.save()
        } catch {
            context.rollback()
            print("Could not prepare VT FOMO demo accounts: \(error)")
        }
    }
}
#endif
