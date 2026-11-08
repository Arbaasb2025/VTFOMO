import Testing
import Foundation
import SwiftData
import LocalAuthentication
@testable import VTFomo

@MainActor
private func testStore() throws -> ModelContainer {
    try ModelContainer(for: AppUser.self, Building.self, Organization.self, Event.self, SavedEvent.self,
                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

@Suite("Organizer approvals")
@MainActor
struct OrganizerApprovalTests {
    private func fixture() throws -> (ModelContainer, Building, Building, AppUser, AppUser) {
        let store = try testStore()
        let hall = Building(id: "lee", name: "Lee", area: "Upper Quad", latitude: 0, longitude: 0)
        let other = Building(id: "aj", name: "AJ", area: "Central", latitude: 0, longitude: 0)
        let resident = AppUser(email: "resident@vt.edu", displayName: "Resident", passwordHash: "x",
                               role: .student, homeBuilding: hall)
        let coordinator = AppUser(email: "coordinator@vt.edu", displayName: "Coordinator", passwordHash: "x",
                                  role: .areaCoordinator, managedArea: "Upper Quad")
        [hall, other].forEach { store.mainContext.insert($0) }
        [resident, coordinator].forEach { store.mainContext.insert($0) }
        try store.mainContext.save()
        return (store, hall, other, resident, coordinator)
    }

    @Test("A request does not grant access; approval persists and revocation removes access")
    func approvalLifecycle() throws {
        let (store, hall, _, resident, coordinator) = try fixture()
        let context = store.mainContext
        try OrganizerApprovalService.request(user: resident, context: context)
        #expect(!resident.canPublishEvents())
        try OrganizerApprovalService.review(user: resident, hall: hall, actor: coordinator, approve: true, context: context)
        #expect(resident.canPublishToBuilding(hall))
        #expect(resident.organizerApprovedByID == coordinator.id)
        #expect(resident.organizerApprovedAt != nil)
        #expect(resident.requestedOrganizerHallID == nil)
        let freshContext = ModelContext(store)
        let saved = try #require(freshContext.fetch(FetchDescriptor<AppUser>()).first { $0.id == resident.id })
        #expect(saved.approvedOrganizerHallID == hall.id)
        try OrganizerApprovalService.revoke(user: resident, hall: hall, actor: coordinator, context: context)
        #expect(!resident.canPublishToBuilding(hall))
        #expect(!resident.canPublishEvents())
        #expect(PublishingPolicy.problem(organizer: resident, visibility: .publicEvent, hallIDs: [], buildings: [hall]) != nil)
    }

    @Test("A coordinator cannot approve a request outside their area")
    func blocksOtherArea() throws {
        let (store, _, other, resident, coordinator) = try fixture()
        resident.homeBuilding = other
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        #expect(throws: OrganizerApprovalService.ApprovalError.self) {
            try OrganizerApprovalService.review(user: resident, hall: other, actor: coordinator, approve: true, context: store.mainContext)
        }
        #expect(resident.role == .student)
        #expect(resident.approvedOrganizerHallID == nil)
    }

    @Test("Residents cannot approve themselves or grant organizer access to others")
    func blocksUnauthorizedActor() throws {
        let (store, hall, _, resident, _) = try fixture()
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        #expect(throws: OrganizerApprovalService.ApprovalError.self) {
            try OrganizerApprovalService.review(user: resident, hall: hall, actor: resident, approve: true, context: store.mainContext)
        }
    }

    @Test("Declining clears the request without granting access")
    func decline() throws {
        let (store, hall, _, resident, coordinator) = try fixture()
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        try OrganizerApprovalService.review(user: resident, hall: hall, actor: coordinator, approve: false, context: store.mainContext)
        #expect(resident.requestedOrganizerHallID == nil)
        #expect(resident.organizerRequestFeedback?.contains("declined") == true)
        #expect(!resident.canPublishEvents())
    }

    @Test("Changing residence halls cannot transfer approval")
    func hallChange() throws {
        let (store, hall, other, resident, coordinator) = try fixture()
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        try OrganizerApprovalService.review(user: resident, hall: hall, actor: coordinator, approve: true, context: store.mainContext)
        resident.homeBuilding = other
        #expect(!resident.canPublishToBuilding(other))
        #expect(!resident.canPublishToBuilding(hall))
        #expect(!resident.canPublishEvents())
    }

    @Test("An old request cannot be approved after a hall change")
    func staleRequest() throws {
        let (store, hall, other, resident, coordinator) = try fixture()
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        resident.homeBuilding = other
        #expect(throws: OrganizerApprovalService.ApprovalError.self) {
            try OrganizerApprovalService.review(user: resident, hall: hall, actor: coordinator, approve: true, context: store.mainContext)
        }
    }

    @Test("Mixed authorized and unauthorized hall selections are rejected, not silently filtered")
    func validatesEveryHall() throws {
        let (store, hall, other, resident, coordinator) = try fixture()
        try OrganizerApprovalService.request(user: resident, context: store.mainContext)
        try OrganizerApprovalService.review(user: resident, hall: hall, actor: coordinator, approve: true, context: store.mainContext)
        #expect(PublishingPolicy.problem(organizer: resident, visibility: .hallOnly, hallIDs: [hall.id], buildings: [hall, other]) == nil)
        #expect(PublishingPolicy.problem(organizer: resident, visibility: .hallOnly, hallIDs: [hall.id, other.id], buildings: [hall, other]) != nil)
        #expect(PublishingPolicy.problem(organizer: resident, visibility: .hallOnly, hallIDs: [], buildings: [hall]) != nil)
    }
}

@MainActor
private struct StubBiometrics: BiometricAuthenticating {
    var isAvailable = true
    var name = "Face ID"
    var symbol = "faceid"
    var result = true
    var failure: LAError.Code?
    func authenticate() async throws -> Bool {
        if let failure { throw LAError(failure) }
        return result
    }
}

@Suite("Returning-user biometric login")
@MainActor
struct BiometricLoginTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "VTFomoTests.\(UUID().uuidString)")!
    }
    private func account(in context: ModelContext) throws -> AppUser {
        let user = AppUser(email: "returning@vt.edu", displayName: "Returning",
                           passwordHash: AuthService.hash("TestPassword1"), role: .student)
        context.insert(user)
        try context.save()
        return user
    }

    @Test("First-time users cannot use biometric login")
    func firstLogin() async throws {
        let store = try testStore()
        let auth = AuthService(defaults: defaults(), biometrics: StubBiometrics())
        #expect(!auth.biometricsAvailable)
        let success = await auth.unlockWithBiometrics(context: store.mainContext)
        #expect(!success)
        #expect(auth.currentUser == nil)
    }

    @Test("A cold launch stays locked, then Face ID restores the remembered account")
    func returningLogin() async throws {
        let store = try testStore()
        let user = try account(in: store.mainContext)
        let settings = defaults()
        let first = AuthService(defaults: settings, biometrics: StubBiometrics())
        try first.logIn(email: user.email, password: "TestPassword1", context: store.mainContext)
        let returning = AuthService(defaults: settings, biometrics: StubBiometrics())
        returning.restoreSession(context: store.mainContext)
        #expect(returning.currentUser == nil)
        #expect(returning.biometricsAvailable)
        let success = await returning.unlockWithBiometrics(context: store.mainContext)
        #expect(success)
        #expect(returning.currentUser?.id == user.id)
        returning.logOut()
        #expect(returning.currentUser == nil)
        #expect(returning.biometricsAvailable)
    }

    @Test("Failure, cancellation and lockout never sign in", arguments: [LAError.Code.authenticationFailed, .userCancel, .biometryLockout, .userFallback])
    func failedScan(code: LAError.Code) async throws {
        let store = try testStore()
        let user = try account(in: store.mainContext)
        let auth = AuthService(defaults: defaults(), biometrics: StubBiometrics(failure: code))
        try auth.logIn(email: user.email, password: "TestPassword1", context: store.mainContext)
        auth.logOut()
        let success = await auth.unlockWithBiometrics(context: store.mainContext)
        #expect(!success)
        #expect(auth.currentUser == nil)
        #expect(!auth.isWorking)
        #expect(code == .userCancel ? auth.errorMessage == nil : auth.errorMessage != nil)
        try auth.logIn(email: user.email, password: "TestPassword1", context: store.mainContext)
        #expect(auth.currentUser?.id == user.id)
    }

    @Test("Forgetting this device removes biometric access")
    func forgetAccount() async throws {
        let store = try testStore()
        let user = try account(in: store.mainContext)
        let auth = AuthService(defaults: defaults(), biometrics: StubBiometrics())
        try auth.logIn(email: user.email, password: "TestPassword1", context: store.mainContext)
        auth.forgetDevice()
        #expect(!auth.biometricsAvailable)
        let success = await auth.unlockWithBiometrics(context: store.mainContext)
        #expect(!success)
        #expect(auth.currentUser == nil)
    }

    @Test("A deleted remembered account cannot be restored")
    func missingAccount() async throws {
        let store = try testStore()
        let user = try account(in: store.mainContext)
        let auth = AuthService(defaults: defaults(), biometrics: StubBiometrics())
        try auth.logIn(email: user.email, password: "TestPassword1", context: store.mainContext)
        auth.logOut()
        store.mainContext.delete(user)
        try store.mainContext.save()
        let success = await auth.unlockWithBiometrics(context: store.mainContext)
        #expect(!success)
        #expect(!auth.biometricsAvailable)
        #expect(auth.currentUser == nil)
    }
}
