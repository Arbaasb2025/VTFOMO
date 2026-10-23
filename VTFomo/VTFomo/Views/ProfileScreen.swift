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

    /// The organizer's own events, newest first.
    private var myEvents: [Event] {
        user.createdEvents.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        List {
            identitySection

            if user.canPublishEvents() {
                dashboardSection
            }

            if user.role == .areaCoordinator || user.role == .admin {
                coordinatorSection
            }

            Section {
                Button("Log Out", role: .destructive) { auth.logOut() }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .sheet(isPresented: $showingHallPicker) {
            hallPicker
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            HStack(spacing: 14) {
                Text(user.initials)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Theme.maroon)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName).font(.headline)
                    Text(user.email).font(.caption).foregroundStyle(.secondary)
                    Text(user.role.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Theme.maroon.opacity(0.14))
                        .foregroundStyle(Theme.maroon)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)

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
            LabeledContent("Area", value: user.managedArea ?? "All areas")
            Text("You can approve organizers for halls in your area, so each hall doesn't have to go through a system administrator.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Area Coordinator")
        }
    }

    // MARK: - Hall picker

    private var hallPicker: some View {
        NavigationStack {
            List(buildings) { hall in
                Button {
                    user.homeBuilding = hall
                    try? context.save()
                    showingHallPicker = false
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
