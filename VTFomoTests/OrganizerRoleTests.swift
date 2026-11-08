import Testing
import Foundation
import SwiftData
@testable import VTFomo

@Suite("Organizer categories and administrator controls")
@MainActor
struct OrganizerRoleTests {
    private func store() throws -> ModelContainer {
        try ModelContainer(for: AppUser.self, Building.self, Organization.self, Event.self, SavedEvent.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private func person(_ email: String, role: UserRole, hall: Building? = nil) -> AppUser {
        AppUser(email: email, displayName: email, passwordHash: "test", role: role, homeBuilding: hall)
    }

    @Test("Both organizer categories can be approved and fully revoked", arguments: OrganizerKind.allCases)
    func categoryLifecycle(kind: OrganizerKind) throws {
        let container = try store()
        let context = container.mainContext
        let hall = Building(id: "test", name: "Test Hall", area: "Upper Quad", latitude: 0, longitude: 0)
        let user = person("person@vt.edu", role: .student, hall: hall)
        let coordinator = person("cord@vt.edu", role: .areaCoordinator)
        coordinator.managedArea = hall.area
        context.insert(hall); context.insert(user); context.insert(coordinator)
        try OrganizerApprovalService.request(user: user, kind: kind, affiliation: "Demo team", context: context)
        #expect(!user.canPublishEvents())
        try OrganizerApprovalService.review(user: user, hall: hall, actor: coordinator, approve: true, context: context)
        #expect(user.organizerKind == kind)
        #expect(user.canPublishEvents())
        // The same grant permits repeated publishing without a new approval.
        for _ in 0..<3 {
            #expect(PublishingPolicy.problem(organizer: user, visibility: .publicEvent, hallIDs: [], buildings: [hall]) == nil)
        }
        try OrganizerApprovalService.revoke(user: user, hall: hall, actor: coordinator, context: context)
        #expect(user.role == .student)
        #expect(user.organizerKind == nil)
        #expect(!user.canPublishEvents())
        #expect(PublishingPolicy.problem(organizer: user, visibility: .publicEvent, hallIDs: [], buildings: [hall]) != nil)
    }

    @Test("Organization membership does not bypass approval")
    func affiliationAloneIsNotPermission() {
        let user = person("member@vt.edu", role: .organizer)
        user.organization = Organization(id: "club", name: "Club", abbreviation: "C", summary: "Test")
        #expect(!user.canPublishEvents())
    }

    @Test("An authorized organizer must supply an affiliation")
    func missingAffiliation() throws {
        let container = try store()
        let hall = Building(id: "test", name: "Test", area: "Upper Quad", latitude: 0, longitude: 0)
        let user = person("member@vt.edu", role: .student, hall: hall)
        container.mainContext.insert(user)
        #expect(throws: OrganizerApprovalService.ApprovalError.self) {
            try OrganizerApprovalService.request(user: user, kind: .authorizedOrganizer, affiliation: "   ", context: container.mainContext)
        }
    }

    @Test("Admin access requires both an allowed email and an explicitly provisioned role")
    func adminGate() {
        #expect(person("arbaasb@gmail.com", role: .admin).role == .admin)
        #expect(person("arbaasb@gmail.com", role: .student).role == .student)
        #expect(person("outsider@vt.edu", role: .admin).role == .student)
        #expect(person("arbaasb@gmail.com.attacker.com", role: .admin).role == .student)
    }

    @Test("An admin can manage coordinators; a coordinator cannot")
    func coordinatorAdministration() throws {
        let container = try store()
        let context = container.mainContext
        let hall = Building(id: "test", name: "Test", area: "Upper Quad", latitude: 0, longitude: 0)
        let admin = person("arbaasb@gmail.com", role: .admin)
        let target = person("candidate@vt.edu", role: .student)
        let coordinator = person("cord@vt.edu", role: .areaCoordinator)
        coordinator.managedArea = hall.area
        context.insert(hall); context.insert(admin); context.insert(target); context.insert(coordinator)
        #expect(throws: AdminManagementService.AccessError.self) {
            try AdminManagementService.setCoordinator(user: target, area: hall.area, actor: coordinator, context: context)
        }
        try AdminManagementService.setCoordinator(user: target, area: hall.area, actor: admin, context: context)
        #expect(target.role == .areaCoordinator)
        #expect(target.managedArea == hall.area)
        try AdminManagementService.setCoordinator(user: target, area: nil, actor: admin, context: context)
        #expect(target.role == .student)
        #expect(!target.canPublishEvents())
    }

    @Test("Admins may edit other organizers' events")
    func adminEditsEvents() {
        let admin = person("arbaasb@gmail.com", role: .admin)
        let event = Event(title: "Partner event", details: "", locationName: "Campus", latitude: 0, longitude: 0,
                          startTime: Date(), endTime: Date().addingTimeInterval(3600))
        #expect(PublishingPolicy.problem(organizer: admin, visibility: .publicEvent, hallIDs: [], buildings: [], editing: event) == nil)
    }

    #if DEBUG
    @Test("Demo setup does not restore coordinator or organizer access on relaunch")
    func demoSeedDoesNotRegrant() throws {
        let container = try store()
        let context = container.mainContext
        SampleData.seedIfNeeded(context: context)
        SampleData.ensureRoleDemoAccounts(context: context)
        let users = try context.fetch(FetchDescriptor<AppUser>())
        let admin = try #require(users.first { $0.email == "arbaasb@gmail.com" })
        let coordinator = try #require(users.first { $0.email == "cord@vt.edu" })
        let sl = try #require(users.first { $0.email == "sl@vt.edu" })
        let hall = try #require(sl.homeBuilding)
        try OrganizerApprovalService.review(user: sl, hall: hall, actor: admin, approve: true, context: context)
        try OrganizerApprovalService.revoke(user: sl, hall: hall, actor: admin, context: context)
        try AdminManagementService.setCoordinator(user: coordinator, area: nil, actor: admin, context: context)
        SampleData.ensureRoleDemoAccounts(context: context)
        #expect(sl.role == .student)
        #expect(sl.requestedOrganizerHallID == nil)
        #expect(coordinator.role == .student)
    }
    #endif
}
