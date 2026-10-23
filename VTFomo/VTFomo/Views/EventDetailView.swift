//
//  EventDetailView.swift
//  VT FOMO
//
//  Everything about one event: description, time, a mini map, photos, the
//  forecast for the start time, and the save / remind-me control.
//
//  The weather block is the app's live REST call. It has three visible states
//  - loading, loaded, unavailable - so the user is never left wondering.
//

import SwiftUI
import SwiftData
import MapKit

struct EventDetailView: View {

    @Environment(\.modelContext) private var context

    let event: Event
    let user: AppUser

    @State private var weather = WeatherService()
    @State private var directions = DirectionsService()
    @State private var showingEditor = false
    @State private var reminderMinutes = 30

    /// The SavedEvent record for this user and event, if one exists.
    private var savedRecord: SavedEvent? {
        user.savedEvents.first { $0.event?.id == event.id }
    }

    private var isSaved: Bool { savedRecord != nil }

    private var canEdit: Bool {
        event.organizer?.id == user.id || user.role == .admin
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                if !event.photoNames.isEmpty { photoStrip }
                detailsBlock
                weatherBlock
                directionsBlock
                miniMap
                hostBlock
                saveBlock
            }
            .padding(16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEditor = true }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CreateEventView(organizer: user, editing: event)
        }
        .task(id: event.id) {
            await weather.load(latitude: event.latitude,
                               longitude: event.longitude,
                               at: event.startTime)
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(event.timeState().label, systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(event.timeState().color)
                if event.isPriority(for: user) {
                    Text("YOUR HALL")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.burntOrange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if event.isCancelled {
                    Text("CANCELLED")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            Text(event.title)
                .font(.title2.bold())

            Label(Theme.rangeText(from: event.startTime, to: event.endTime),
                  systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(event.locationName, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(event.photoNames, id: \.self) { name in
                    // Photos live on disk, not in the database. PhotoStore
                    // checks the documents directory first, then the asset
                    // catalog, so both uploaded and seeded images work.
                    if let image = PhotoStore.loadImage(named: name) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 240, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                        style: .continuous))
                    }
                }
            }
        }
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(event.details)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var weatherBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weather at start time").font(.headline)

            switch weather.state {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Checking the forecast…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

            case .loaded(let value):
                HStack(spacing: 12) {
                    Image(systemName: value.symbolName)
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.burntOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value.summaryLine)
                            .font(.subheadline.weight(.medium))
                        if value.isStale {
                            Text("Offline — last checked \(Theme.timeFormatter.string(from: value.fetchedAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            case .unavailable:
                Label("Forecast not available for this date.", systemImage: "cloud.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Walking time to the event, plus a handoff to Apple Maps for turn-by-turn.
    private var directionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch directions.state {

            case .idle, .needsPermission:
                Button {
                    directions.route(to: event.coordinate)
                } label: {
                    Label("How far is it?", systemImage: "figure.walk")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .locating:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finding you\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

            case .ready:
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(Theme.maroon)
                        Text(directions.state.summary ?? "")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    Button {
                        directions.openInMaps(coordinate: event.coordinate,
                                              name: event.locationName)
                    } label: {
                        Label("Walk me there", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .unavailable(let reason):
                VStack(alignment: .leading, spacing: 8) {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        directions.openInMaps(coordinate: event.coordinate,
                                              name: event.locationName)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardStyle()
    }

    private var miniMap: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(center: event.coordinate,
                               span: MKCoordinateSpan(latitudeDelta: 0.003,
                                                      longitudeDelta: 0.003))
        )) {
            Annotation(event.title, coordinate: event.coordinate) {
                EventPin(event: event, isPriority: event.isPriority(for: user))
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .allowsHitTesting(false)
    }

    private var hostBlock: some View {
        HStack(spacing: 12) {
            Text(event.organizer?.initials ?? "VT")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.maroon)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(event.hostName).font(.subheadline.weight(.medium))
                Text(event.visibility == .hallOnly ? "Residents only" : "Open to all students")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardStyle()
    }

    private var saveBlock: some View {
        VStack(spacing: 12) {
            Button(action: toggleSave) {
                Label(isSaved ? "Saved" : "Save this event",
                      systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isSaved ? Theme.green : Theme.maroon)

            if isSaved {
                Picker("Remind me", selection: $reminderMinutes) {
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                    Text("1 hour before").tag(60)
                    Text("1 day before").tag(1440)
                }
                .pickerStyle(.segmented)
                .onChange(of: reminderMinutes) { _, newValue in
                    Task { await rescheduleReminder(minutes: newValue) }
                }
            }
        }
        .onAppear {
            if let record = savedRecord { reminderMinutes = record.reminderMinutesBefore }
        }
    }

    // MARK: - Actions

    private func toggleSave() {
        if let record = savedRecord {
            if let id = record.notificationID {
                NotificationService.cancelReminder(id: id)
            }
            context.delete(record)
        } else {
            let record = SavedEvent(user: user,
                                    event: event,
                                    reminderMinutesBefore: reminderMinutes)
            context.insert(record)
            Task {
                let id = await NotificationService.scheduleReminder(
                    for: event, minutesBefore: reminderMinutes
                )
                record.notificationID = id
                try? context.save()
            }
        }
        try? context.save()
    }

    private func rescheduleReminder(minutes: Int) async {
        guard let record = savedRecord else { return }
        if let old = record.notificationID {
            NotificationService.cancelReminder(id: old)
        }
        record.reminderMinutesBefore = minutes
        record.notificationID = await NotificationService.scheduleReminder(
            for: event, minutesBefore: minutes
        )
        try? context.save()
    }
}
