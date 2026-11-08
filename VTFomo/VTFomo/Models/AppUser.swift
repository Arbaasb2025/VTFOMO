//
//  AppUser.swift
//  VT FOMO
//
//  A person with an account. One model covers every user type; what somebody
//  is allowed to do comes from `role` plus a scope (their building or their
//  organization), not from a subclass. This is deliberate: a student can be
//  an SL in one hall AND an officer of a club, and an inheritance tree would
//  force us to pick one.
//

import Foundation
import SwiftData

@Model
final class AppUser {

    // MARK: - Stored properties

    @Attribute(.unique) var id: String
    /// Must end in @vt.edu. Enforced in Validation.swift at sign-up.
    @Attribute(.unique) var email: String
    var displayName: String
    /// SHA-256 of the password. See AuthService for the caveat about this.
    var passwordHash: String
    /// UserRole.rawValue. Stored as a String so it works inside #Predicate.
    var roleRaw: String
    /// For an Area Coordinator, the residential area they are responsible for.
    var managedArea: String?
    // Optional fields keep existing stores compatible; existing roles do not
    // silently receive hall approval when upgrading.
    var requestedOrganizerKindRaw: String?
    var approvedOrganizerKindRaw: String?
    var requestedAffiliation: String?
    var approvedAffiliation: String?
    var requestedOrganizerHallID: String?
    var approvedOrganizerHallID: String?
    var organizerApprovedByID: String?
    var organizerApprovedAt: Date?
    var organizerRequestFeedback: String?
    var createdAt: Date

    // MARK: - Relationships

    /// The residence hall this user lives in. Picked during onboarding.
    var homeBuilding: Building?

    /// The club this user is an officer of, if any.
    var organization: Organization?

    /// Events this user created.
    @Relationship(deleteRule: .cascade, inverse: \Event.organizer)
    var createdEvents: [Event] = []


    @Relationship(deleteRule: .cascade, inverse: \SavedEvent.user)
    var savedEvents: [SavedEvent] = []

    // MARK: - Init

    init(id: String = UUID().uuidString,
         email: String,
         displayName: String,
         passwordHash: String,
         role: UserRole,
         managedArea: String? = nil,
         homeBuilding: Building? = nil,
         organization: Organization? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.passwordHash = passwordHash
        self.roleRaw = role.rawValue
        self.managedArea = managedArea
        self.homeBuilding = homeBuilding
        self.organization = organization
        self.createdAt = Date()
    }

    // MARK: - Computed

    var role: UserRole {
        get {
            let stored = UserRole(rawValue: roleRaw) ?? .student
            if stored == .admin && !AdminAccess.permits(email: email, storedRole: roleRaw) { return .student }
            return stored
        }
        set { roleRaw = newValue.rawValue }
    }

    var organizerKind: OrganizerKind? {
        guard approvedOrganizerHallID != nil else { return nil }
        // Existing hall approvals migrate as Student Leader approvals.
        return OrganizerKind(rawValue: approvedOrganizerKindRaw ?? "") ?? .studentLeader
    }

    var requestedOrganizerKind: OrganizerKind {
        OrganizerKind(rawValue: requestedOrganizerKindRaw ?? "") ?? .studentLeader
    }

    var accessLabel: String {
        if role == .organizer {
            return canPublishEvents() ? organizerKind?.displayName ?? "Organizer" : "Organizer · approval required"
        }
        return role.displayName
    }

    /// First letter of each word, used for the avatar circle.
    var initials: String {
        displayName
            .split(separator: " ")
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    // MARK: - Permissions

    /// Can this user publish events at all?
    func canPublishEvents() -> Bool {
        switch role {
        case .admin, .areaCoordinator: return true
        case .organizer:
            return homeBuilding.map { canPublishToBuilding($0) } ?? false
        case .student: return false
        }
    }

    func canPublishToBuilding(_ building: Building) -> Bool {
        switch role {
        case .admin:
            return true
        case .areaCoordinator:
            return building.area == managedArea
        case .organizer:
            return building.id == homeBuilding?.id && building.id == approvedOrganizerHallID
        case .student:
            return false
        }
    }


    func canGrantRole(_ target: UserRole, inArea area: String) -> Bool {
        guard target.rank < role.rank else { return false }
        switch role {
        case .admin:           return true
        case .areaCoordinator: return area == managedArea
        default:               return false
        }
    }
}
