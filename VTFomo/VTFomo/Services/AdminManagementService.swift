import Foundation
import SwiftData

enum AdminManagementService {
    enum AccessError: LocalizedError {
        case forbidden, invalidArea
        var errorDescription: String? {
            switch self {
            case .forbidden: return "Only an authorized admin can manage coordinator access. Admin accounts cannot be changed here."
            case .invalidArea: return "Choose an existing residential area."
            }
        }
    }

    static func setCoordinator(user: AppUser, area: String?, actor: AppUser,
                               context: ModelContext) throws {
        guard actor.role == .admin, user.id != actor.id,
              user.roleRaw != UserRole.admin.rawValue else { throw AccessError.forbidden }
        if let area {
            let buildings = try context.fetch(FetchDescriptor<Building>())
            guard buildings.contains(where: { $0.area == area }) else { throw AccessError.invalidArea }
        }
        // Role changes invalidate any old organizer grant so removing a
        // coordinator cannot accidentally restore a previous publishing role.
        let old = (user.roleRaw, user.managedArea, user.approvedOrganizerHallID,
                   user.requestedOrganizerHallID, user.approvedOrganizerKindRaw,
                   user.requestedOrganizerKindRaw, user.organizerApprovedByID,
                   user.organizerApprovedAt, user.approvedAffiliation,
                   user.requestedAffiliation, user.organizerRequestFeedback)
        user.role = area == nil ? .student : .areaCoordinator
        user.managedArea = area
        user.approvedOrganizerHallID = nil
        user.requestedOrganizerHallID = nil
        user.approvedOrganizerKindRaw = nil
        user.requestedOrganizerKindRaw = nil
        user.organizerApprovedByID = nil
        user.organizerApprovedAt = nil
        user.approvedAffiliation = nil
        user.requestedAffiliation = nil
        user.organizerRequestFeedback = area.map { "Assigned as coordinator for \($0)." } ?? "Coordinator access removed."
        do { try context.save() }
        catch {
            (user.roleRaw, user.managedArea, user.approvedOrganizerHallID,
             user.requestedOrganizerHallID, user.approvedOrganizerKindRaw,
             user.requestedOrganizerKindRaw, user.organizerApprovedByID,
             user.organizerApprovedAt, user.approvedAffiliation,
             user.requestedAffiliation, user.organizerRequestFeedback) = old
            throw error
        }
    }
}
