//
//  ProfileScreen.swift
//  VT FOMO
//
//  Account details, hall, and - for organizers - the dashboard of their own
//  events with save counts (Requirement 5).
//

import SwiftUI
import SwiftData

struct ProfileScreen: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    let user: AppUser

    @Query(sort: \Building.name) private var buildings: [Building]
    @State private var showingHallPicker = false
    @State private var problem: String?
    @State private var requestedKind: OrganizerKind = .studentLeader
    @State private var affiliation = ""

    /// The organizer's own events, newest first.
    private var myEvents: [Event] {
        user.createdEvents.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        List {
            identitySection
            if user.role == .student || user.role == .organizer {
                organizerRequestSection
            }

            if user.canPublishEvents() {
                dashboardSection
            }

            if user.role == .areaCoordinator || user.role == .admin {
                coordinatorSection
            }
            if user.role == .admin {
                Section("Administration") {
                    NavigationLink { AdminManagementView(admin: user) } label: {
                        Label("Manage coordinators", systemImage: "person.2.fill")
                    }
                    NavigationLink { AdminEventsView(admin: user) } label: {
                        Label("Manage all events", systemImage: "calendar.badge.checkmark")
                    }
                }
            }

            Section {
                Button(role: .destructive) { auth.logOut() } label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right") }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.maroon)
        .navigationTitle("Profile")
        .arrival()
        .alert("Unable to save", isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) { Button("OK") { problem = nil } } message: { Text(problem ?? "") }
        .sheet(isPresented: $showingHallPicker) {
            hallPicker
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            HStack(spacing: 14) {
                Text(String(user.initials.prefix(2)))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.maroon)
                    .frame(width: 54, height: 54)
                    .background(Theme.maroon.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName).font(.headline)
                    Text(user.email).font(.caption).foregroundStyle(.secondary)
                    Text(user.accessLabel)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Theme.maroon.opacity(0.08))
                        .foregroundStyle(Theme.maroon)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.maroon)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            LabeledContent("Residence hall",
                           value: user.homeBuilding?.name ?? "Not set")
            Button("Change hall") { showingHallPicker = true }
                .font(.footnote)
        }
    }

    private var dashboardSection: some View {
        Section {
            if myEvents.isEmpty {
                Text("You haven't published anything yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(myEvents) { event in
                    NavigationLink {
                        EventDetailView(event: event, user: user)
                    } label: {
                        EventRow(event: event, showSaveCount: true)
                    }
                }
            }
        } header: {
            Text("My events")
        } footer: {
            // FUNCTIONAL: reduce across every event this organizer created.
            Text("\(myEvents.count) events · \(EventFilter.totalSaves(myEvents)) total saves")
        }
    }

    private var coordinatorSection: some View {
        Section {
            LabeledContent("Area", value: user.role == .admin ? "All areas" : user.managedArea ?? "Not assigned")
            NavigationLink { OrganizerApprovalsView(coordinator: user) } label: {
                Label("Review organizer requests", systemImage: "person.2.fill")
            }
            Text("You can approve organizers for halls in your area, so each hall doesn't have to go through a system administrator.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(user.role == .admin ? "Organizer administration" : "Area Coordinator")
        }
    }

    private var organizerRequestSection: some View {
        Section("Organizer access") {
            if let hall = user.homeBuilding {
                if user.canPublishToBuilding(hall) {
                    Label("\(user.organizerKind?.displayName ?? "Organizer") · \(hall.name)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.green)
                } else if user.requestedOrganizerHallID == hall.id {
                    Label("\(user.requestedOrganizerKind.displayName) · awaiting approval for \(hall.name)", systemImage: "clock")
                } else {
                    Text("Request approval from your Area Coordinator to publish events for \(hall.name).")
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker("Organizer type", selection: $requestedKind) {
                        ForEach(OrganizerKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    if requestedKind == .authorizedOrganizer {
                        TextField("University group or team", text: $affiliation)
                        Text("Your coordinator will verify your affiliation before approval.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Request organizer approval") {
                        do { try OrganizerApprovalService.request(user: user, kind: requestedKind, affiliation: affiliation, context: context) }
                        catch { problem = error.localizedDescription }
                    }
                    .disabled(requestedKind == .authorizedOrganizer && affiliation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if let feedback = user.organizerRequestFeedback {
                Text(feedback).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hall picker

    private var hallPicker: some View {
        NavigationStack {
            List(buildings) { hall in
                Button {
                    let oldHall = user.homeBuilding
                    let oldRequest = user.requestedOrganizerHallID
                    let oldFeedback = user.organizerRequestFeedback
                    user.homeBuilding = hall
                    if oldHall?.id != hall.id {
                        user.requestedOrganizerHallID = nil
                        user.organizerRequestFeedback = nil
                    }
                    do {
                        try context.save()
                        showingHallPicker = false
                    } catch {
                        user.homeBuilding = oldHall
                        user.requestedOrganizerHallID = oldRequest
                        user.organizerRequestFeedback = oldFeedback
                        showingHallPicker = false
                        problem = "Your hall could not be saved. Please try again."
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(hall.name).foregroundStyle(.primary)
                            Text(hall.area).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if user.homeBuilding?.id == hall.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.maroon)
                        }
                    }
                }
            }
            .navigationTitle("Residence hall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingHallPicker = false }
                }
            }
        }
    }
}
