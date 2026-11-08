import SwiftUI
import SwiftData

struct AdminManagementView: View {
    @Environment(\.modelContext) private var context
    let admin: AppUser
    @Query(sort: \AppUser.displayName) private var users: [AppUser]
    @Query(sort: \Building.name) private var buildings: [Building]
    @State private var search = ""
    @State private var target: AppUser?
    @State private var newArea: String?
    @State private var confirming = false
    @State private var problem: String?

    private var areas: [String] { Array(Set(buildings.map(\.area))).sorted() }
    private var matches: [AppUser] {
        users.filter { $0.roleRaw != UserRole.admin.rawValue &&
            (search.isEmpty || $0.email.localizedCaseInsensitiveContains(search) || $0.displayName.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        List {
            if admin.role == .admin {
                Section {
                    Text("Assign an area to a coordinator or remove their coordinator access. Removing access returns them to student permissions.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(matches) { user in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName).font(.headline)
                        Text(user.email).font(.caption).foregroundStyle(.secondary)
                        Text(user.accessLabel + (user.managedArea.map { " · \($0)" } ?? ""))
                            .font(.caption)
                        Menu("Assign coordinator area") {
                            ForEach(areas, id: \.self) { area in
                                Button(area) { prepare(user, area: area) }
                            }
                        }.buttonStyle(.bordered)
                        if user.role == .areaCoordinator {
                            Button("Remove coordinator access", role: .destructive) { prepare(user, area: nil) }
                                .buttonStyle(.bordered)
                        }
                    }.padding(.vertical, 4)
                }
            } else {
                Text("Administrator access is required.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.maroon)
        .searchable(text: $search, prompt: "Name or email")
        .navigationTitle("Manage coordinators")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Change account permissions?", isPresented: $confirming, titleVisibility: .visible) {
            Button(newArea == nil ? "Remove coordinator access" : "Assign coordinator") {
                guard let target else { return }
                do { try AdminManagementService.setCoordinator(user: target, area: newArea, actor: admin, context: context) }
                catch { problem = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(target?.email ?? "")\n\(newArea.map { "Coordinator for \($0)." } ?? "Returns to student access.") Existing organizer approvals will be cleared.")
        }
        .alert("Unable to change access", isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) { Button("OK") { problem = nil } } message: { Text(problem ?? "") }
    }

    private func prepare(_ user: AppUser, area: String?) {
        target = user
        newArea = area
        confirming = true
    }
}

struct AdminEventsView: View {
    let admin: AppUser
    @Query(sort: \Event.startTime, order: .reverse) private var events: [Event]
    @State private var search = ""
    var body: some View {
        List {
            if admin.role == .admin {
                ForEach(events.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { event in
                    NavigationLink {
                        EventDetailView(event: event, user: admin)
                    } label: {
                        EventRow(event: event, showSaveCount: true)
                    }
                }
            } else { Text("Administrator access is required.") }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.maroon)
        .searchable(text: $search, prompt: "Event title")
        .navigationTitle("All events")
        .navigationBarTitleDisplayMode(.inline)
    }
}
