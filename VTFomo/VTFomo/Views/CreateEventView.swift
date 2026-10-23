//
//  CreateEventView.swift
//  VT FOMO
//
//  The organizer's event editor. Handles both creating a new event and editing
//  an existing one - the only difference is whether `editing` is nil.
//
//  The hall picker only lists halls this organizer is actually allowed to post
//  to (see AppUser.canPublishToBuilding). Hiding the option is better than
//  showing it and rejecting the tap, which is one of the 8 golden rules:
//  prevent errors rather than report them.
//

import SwiftUI
import SwiftData
import MapKit

struct CreateEventView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let organizer: AppUser
    /// nil when creating, set when editing.
    var editing: Event? = nil

    @Query(sort: \Building.name) private var buildings: [Building]

    @State private var title = ""
    @State private var details = ""
    @State private var locationName = ""
    @State private var start = Date().addingTimeInterval(3600)
    @State private var end = Date().addingTimeInterval(7200)
    @State private var tag: EventTag = .social
    @State private var visibility: EventVisibility = .publicEvent
    @State private var selectedHallIDs: Set<String> = []
    @State private var coordinate = CLLocationCoordinate2D(latitude: 37.2277,
                                                           longitude: -80.4229)
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.2277, longitude: -80.4229),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    )
    @State private var photoNames: [String] = []
    @State private var problem: String?
    @State private var showingDeleteConfirm = false

    /// Halls this organizer may restrict an event to.
    private var allowedHalls: [Building] {
        buildings.filter { organizer.canPublishToBuilding($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                whenSection
                whereSection
                photosSection
                visibilitySection
                if editing != nil { dangerSection }
            }
            .navigationTitle(editing == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Publish" : "Save", action: save)
                }
            }
            .onAppear(perform: loadExistingIfEditing)
            .alert("Check your event",
                   isPresented: .constant(problem != nil),
                   actions: { Button("OK") { problem = nil } },
                   message: { Text(problem ?? "") })
        }
    }

    // MARK: - Sections

    private var basicsSection: some View {
        Section("Basics") {
            TextField("Title", text: $title)
            TextField("What's happening?", text: $details, axis: .vertical)
                .lineLimit(3...8)
            Picker("Category", selection: $tag) {
                ForEach(EventTag.allCases) { option in
                    Label(option.displayName, systemImage: option.symbolName)
                        .tag(option)
                }
            }
        }
    }

    private var whenSection: some View {
        Section("When") {
            DatePicker("Starts", selection: $start)
            DatePicker("Ends", selection: $end)
        }
    }

    private var whereSection: some View {
        Section {
            TextField("Location name (e.g. Pritchard Main Lounge)",
                      text: $locationName)

            ZStack {
                Map(position: $camera)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onMapCameraChange(frequency: .onEnd) { ctx in
                        // The pin stays fixed in the middle of the map and the
                        // map moves underneath it, which is far easier than
                        // trying to drop a pin accurately with a fingertip.
                        coordinate = ctx.camera.centerCoordinate
                    }

                Image(systemName: "mappin")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.maroon)
                    .shadow(radius: 2)
                    .offset(y: -12)
                    .allowsHitTesting(false)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

        } header: {
            Text("Where")
        } footer: {
            Text("Move the map so the pin sits on your location.")
        }
    }

    private var photosSection: some View {
        Section {
            PhotoPickerRow(photoNames: $photoNames)
        } header: {
            Text("Photos")
        } footer: {
            Text("Shown on the event page and in the list. Pictures from a previous run of the event work well.")
        }
    }

    private var visibilitySection: some View {
        Section {
            Picker("Who can see it", selection: $visibility) {
                ForEach(EventVisibility.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if visibility == .hallOnly {
                if allowedHalls.isEmpty {
                    Text("You aren't assigned to a hall yet, so you can't post a hall-only event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedHalls) { hall in
                        Button {
                            if selectedHallIDs.contains(hall.id) {
                                selectedHallIDs.remove(hall.id)
                            } else {
                                selectedHallIDs.insert(hall.id)
                            }
                        } label: {
                            HStack {
                                Text(hall.name).foregroundStyle(.primary)
                                Spacer()
                                if selectedHallIDs.contains(hall.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.maroon)
                                }
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Visibility")
        } footer: {
            Text(visibility == .publicEvent
                 ? "Everyone on campus will see this event."
                 : "Only residents of the halls you pick will see it. You can only pick halls you're assigned to.")
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete Event", systemImage: "trash")
            }
            .confirmationDialog("Delete this event?",
                                isPresented: $showingDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteEvent)
                Button("Keep it", role: .cancel) { }
            } message: {
                Text("Anyone who saved it will stop getting reminders.")
            }
        }
    }

    // MARK: - Load / Save

    private func loadExistingIfEditing() {
        guard let event = editing else {
            // New event defaults to the organizer's own hall.
            if let hall = organizer.homeBuilding {
                coordinate = hall.coordinate
                camera = .region(MKCoordinateRegion(
                    center: hall.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                ))
            }
            return
        }
        title = event.title
        details = event.details
        locationName = event.locationName
        start = event.startTime
        end = event.endTime
        tag = event.tag
        visibility = event.visibility
        selectedHallIDs = Set(event.visibleBuildingIDs)
        photoNames = event.photoNames
        coordinate = event.coordinate
        camera = .region(MKCoordinateRegion(
            center: event.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        ))
    }

    private func save() {
        if let message = Validation.eventProblem(title: title, start: start, end: end) {
            problem = message
            return
        }
        if visibility == .hallOnly && selectedHallIDs.isEmpty {
            problem = "Pick at least one hall, or make the event public."
            return
        }

        // Defence in depth: even though the UI only offers allowed halls, we
        // check again here. In a real backend this same check runs server-side.
        let permittedIDs = Set(allowedHalls.map(\.id))
        let finalHallIDs = selectedHallIDs.intersection(permittedIDs)

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let event = editing {
            event.title = cleanTitle
            event.details = details
            event.locationName = cleanLocation.isEmpty ? "Virginia Tech" : cleanLocation
            event.startTime = start
            event.endTime = end
            event.tag = tag
            event.visibility = visibility
            event.visibleBuildingIDs = Array(finalHallIDs)
            event.photoNames = photoNames
            event.latitude = coordinate.latitude
            event.longitude = coordinate.longitude
        } else {
            let event = Event(
                title: cleanTitle,
                details: details,
                locationName: cleanLocation.isEmpty ? "Virginia Tech" : cleanLocation,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                startTime: start,
                endTime: end,
                visibility: visibility,
                tag: tag,
                visibleBuildingIDs: Array(finalHallIDs),
                photoNames: photoNames,
                organizer: organizer,
                organization: organizer.organization
            )
            context.insert(event)
        }

        try? context.save()
        dismiss()
    }

    private func deleteEvent() {
        guard let event = editing else { return }
        // Cancel any reminders people had set for it.
        event.savedBy
            .compactMap(\.notificationID)
            .forEach(NotificationService.cancelReminder)
        context.delete(event)
        try? context.save()
        dismiss()
    }
}
