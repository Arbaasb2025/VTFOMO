import Foundation
import SwiftData

/// Local approval rules. A shared backend must enforce these same rules when
/// accounts and events are synchronized across devices.
enum OrganizerApprovalService {
    enum ApprovalError: LocalizedError {
        case notAllowed, invalidRequest
        var errorDescription: String? {
            switch self {
            case .notAllowed: return "You can only manage organizers for halls in your area."
            case .invalidRequest: return "This request is no longer valid. Refresh and try again."
            }
        }
    }

    static func canManage(actor: AppUser, hall: Building) -> Bool {
        actor.role == .admin || (actor.role == .areaCoordinator && actor.managedArea == hall.area)
    }

    static func request(user: AppUser, kind: OrganizerKind = .studentLeader, affiliation: String = "", context: ModelContext) throws {
        guard user.role == .student || user.role == .organizer,
              let hall = user.homeBuilding, !user.canPublishToBuilding(hall) else {
            throw ApprovalError.invalidRequest
        }
        let cleanAffiliation = affiliation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind != .authorizedOrganizer || !cleanAffiliation.isEmpty else { throw ApprovalError.invalidRequest }
        guard cleanAffiliation.count <= 120 else { throw ApprovalError.invalidRequest }
        try update(user, context: context) {
            user.requestedOrganizerKindRaw = kind.rawValue
            user.requestedAffiliation = kind == .authorizedOrganizer ? cleanAffiliation : nil
            user.requestedOrganizerHallID = hall.id
            user.organizerRequestFeedback = nil
        }
    }

    static func review(user: AppUser, hall: Building, actor: AppUser,
                       approve: Bool, context: ModelContext) throws {
        guard actor.id != user.id, canManage(actor: actor, hall: hall) else {
            throw ApprovalError.notAllowed
        }
        guard user.role == .student || user.role == .organizer,
              user.requestedOrganizerHallID == hall.id,
              user.homeBuilding?.id == hall.id else { throw ApprovalError.invalidRequest }
        try update(user, context: context) {
            let kind = user.requestedOrganizerKind
            let affiliation = user.requestedAffiliation
            user.requestedOrganizerHallID = nil
            user.requestedOrganizerKindRaw = nil
            user.requestedAffiliation = nil
            if approve {
                user.role = .organizer
                user.approvedOrganizerKindRaw = kind.rawValue
                user.approvedAffiliation = affiliation
                user.approvedOrganizerHallID = hall.id
                user.organizerApprovedByID = actor.id
                user.organizerApprovedAt = Date()
                user.organizerRequestFeedback = "Approved as \(kind.displayName) for \(hall.name)."
            } else {
                user.organizerRequestFeedback = "Your request for \(hall.name) was declined. Contact your Area Coordinator before requesting again."
            }
        }
    }

    static func revoke(user: AppUser, hall: Building, actor: AppUser,
                       context: ModelContext) throws {
        guard actor.id != user.id, canManage(actor: actor, hall: hall) else {
            throw ApprovalError.notAllowed
        }
        guard user.role == .organizer, user.approvedOrganizerHallID == hall.id else {
            throw ApprovalError.invalidRequest
        }
        try update(user, context: context) {
            user.approvedOrganizerHallID = nil
            user.approvedOrganizerKindRaw = nil
            user.approvedAffiliation = nil
            user.requestedOrganizerHallID = nil
            user.requestedOrganizerKindRaw = nil
            user.requestedAffiliation = nil
            user.role = .student
            user.organizerApprovedByID = nil
            user.organizerApprovedAt = nil
            user.organizerRequestFeedback = "Your organizer approval for \(hall.name) was revoked."
        }
    }

    private static func update(_ user: AppUser, context: ModelContext,
                               changes: () -> Void) throws {
        let old = (user.roleRaw, user.requestedOrganizerHallID, user.approvedOrganizerHallID,
                   user.organizerApprovedByID, user.organizerApprovedAt, user.organizerRequestFeedback)
        let kindState = (user.requestedOrganizerKindRaw, user.approvedOrganizerKindRaw,
                         user.requestedAffiliation, user.approvedAffiliation)
        changes()
        do { try context.save() }
        catch {
            (user.roleRaw, user.requestedOrganizerHallID, user.approvedOrganizerHallID,
             user.organizerApprovedByID, user.organizerApprovedAt, user.organizerRequestFeedback) = old
            (user.requestedOrganizerKindRaw, user.approvedOrganizerKindRaw,
             user.requestedAffiliation, user.approvedAffiliation) = kindState
            throw error
        }
    }
}

enum PublishingPolicy {
    static func problem(organizer: AppUser, visibility: EventVisibility,
                        hallIDs: Set<String>, buildings: [Building], editing: Event? = nil) -> String? {
        guard organizer.canPublishEvents() else {
            return "You need organizer approval before publishing events."
        }
        if let editing, editing.organizer?.id != organizer.id && organizer.role != .admin {
            return "You can only edit your own events."
        }
        if visibility == .hallOnly {
            guard !hallIDs.isEmpty else { return "Pick at least one approved hall." }
            let permitted = Set(buildings.filter { organizer.canPublishToBuilding($0) }.map(\.id))
            guard hallIDs.isSubset(of: permitted) else {
                return "Your hall approval has changed. Select only halls you are approved to publish to."
            }
        }
        return nil
    }
}
