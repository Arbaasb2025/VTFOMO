import SwiftUI
import SwiftData

struct OrganizerApprovalsView: View {
    @Environment(\.modelContext) private var context
    let coordinator: AppUser
    @Query(sort: \AppUser.displayName) private var users: [AppUser]
    @Query(sort: \Building.name) private var buildings: [Building]
    @State private var problem: String?
    @State private var revokeTarget: AppUser?

    private var managedHalls: [Building] {
        buildings.filter { OrganizerApprovalService.canManage(actor: coordinator, hall: $0) }
    }
    private var requests: [AppUser] {
        users.filter { user in
            (user.role == .student || user.role == .organizer) &&
            user.id != coordinator.id &&
            managedHalls.contains { $0.id == user.requestedOrganizerHallID && $0.id == user.homeBuilding?.id }
        }
    }
    private var approved: [AppUser] {
        users.filter { user in
            user.role == .organizer && managedHalls.contains { $0.id == user.approvedOrganizerHallID }
        }
    }

    var body: some View {
        List {
            Section {
                Text(coordinator.role == .admin ? "All residence halls" : coordinator.managedArea ?? "No area assigned")
                HStack(spacing: 24) {
                    Label("\(requests.count) pending", systemImage: "clock")
                    Label("\(approved.count) approved", systemImage: "checkmark.seal")
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.maroon)
                .padding(.vertical, 6)
                Text("Review the people bringing your community together. Approval stays active until revoked.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Pending requests (\(requests.count))") {
                if requests.isEmpty { Text("No requests waiting for review.").foregroundStyle(.secondary) }
                ForEach(requests) { user in
                    VStack(alignment: .leading, spacing: 10) {
                        identity(user, hallID: user.requestedOrganizerHallID)
                        HStack {
                            Button("Approve") { review(user, approve: true) }
                                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.maroon)
                            Button("Decline", role: .destructive) { review(user, approve: false) }
                                .buttonStyle(.bordered)
                        }
                    }.padding(.vertical, 4)
                }
            }
            ForEach(OrganizerKind.allCases) { kind in
                Section(kind.displayName) {
                    let group = approved.filter { $0.organizerKind == kind }
                    if group.isEmpty { Text("No approved organizers in this group.").foregroundStyle(.secondary) }
                    ForEach(group) { user in
                        VStack(alignment: .leading, spacing: 10) {
                            identity(user, hallID: user.approvedOrganizerHallID, approved: true)
                            Button("Revoke approval", role: .destructive) { revokeTarget = user }
                                .buttonStyle(.bordered)
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.maroon)
        .navigationTitle("Organizer approvals")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to update approval", isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) { Button("OK") { problem = nil } } message: { Text(problem ?? "") }
        .confirmationDialog("Revoke organizer approval?", isPresented: Binding(
            get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Revoke approval", role: .destructive) {
                if let user = revokeTarget,
                   let hall = buildings.first(where: { $0.id == user.approvedOrganizerHallID }) {
                    do { try OrganizerApprovalService.revoke(user: user, hall: hall, actor: coordinator, context: context) }
                    catch { problem = error.localizedDescription }
                }
                revokeTarget = nil
            }
            Button("Cancel", role: .cancel) { revokeTarget = nil }
        } message: {
            Text("They will return to student access and cannot publish or edit events. Existing events remain visible for admin review.")
        }
    }

    private func identity(_ user: AppUser, hallID: String?, approved: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(user.displayName, systemImage: approved ? "checkmark.seal.fill" : "person.crop.circle")
                .font(.headline).foregroundStyle(Theme.maroon)
            Text(user.email).font(.caption).foregroundStyle(.secondary)
            Text(approved ? user.organizerKind?.displayName ?? "Organizer" : user.requestedOrganizerKind.displayName)
                .font(.caption.bold()).foregroundStyle(Theme.maroon)
            if let affiliation = approved ? user.approvedAffiliation : user.requestedAffiliation, !affiliation.isEmpty {
                Text(affiliation).font(.caption)
            }
            Text(buildings.first { $0.id == hallID }?.name ?? "Unknown hall").font(.subheadline)
        }
    }

    private func review(_ user: AppUser, approve: Bool) {
        guard let hall = buildings.first(where: { $0.id == user.requestedOrganizerHallID }) else { return }
        do { try OrganizerApprovalService.review(user: user, hall: hall, actor: coordinator, approve: approve, context: context) }
        catch { problem = error.localizedDescription }
    }
}
