//
//  MapScreen.swift
//  VT FOMO
//
//  The main screen: a map of campus with a pin for every event the signed-in
//  user is allowed to see.
//
//  Pin colour encodes time (green = happening now, orange = starting soon,
//  maroon = upcoming, grey = ended) and pins for the user's own hall are drawn
//  larger with a ring, which is Requirement 8 - own-hall events highlighted.
//

import SwiftUI
import SwiftData
import MapKit

struct MapScreen: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    let user: AppUser
    @Binding var options: FilterOptions
    @Binding var selectedEvent: Event?

    @Query private var allEvents: [Event]

    /// The default view: the whole of campus, centred on the Drillfield.
    static let campusRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.2277, longitude: -80.4229),
        span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
    )

    @State private var camera: MapCameraPosition = .region(MapScreen.campusRegion)
    @State private var showingCreate = false
    @State private var location = LocationProvider()
    @State private var sheetDetent: CampusSheet.Detent = .peek

    /// The events to draw. Recomputed whenever the query or the filters change.
    private var events: [Event] {
        EventFilter.visibleEvents(from: allEvents, for: user, options: options)
    }

    var body: some View {
        ZStack(alignment: .top) {
            map

            VStack(spacing: 0) {
                FilterBar(options: $options, counts: EventFilter.tagCounts(events))
                Spacer()
            }

            // The events themselves, sitting over the map. This is the content;
            // the map behind it is context.
            CampusSheet(events: events,
                        user: user,
                        selectedEvent: $selectedEvent,
                        detent: $sheetDetent)
        }
        .navigationTitle("Campus Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if user.canPublishEvents() {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Label("New Event", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateEventView(organizer: user)
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(event: event, user: user)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            ForEach(events) { event in
                Annotation(event.title, coordinate: event.coordinate) {
                    EventPin(event: event, isPriority: event.isPriority(for: user))
                        .onTapGesture { selectedEvent = event }
                }
            }

            // The blue dot. Only draws once permission exists, which is why
            // LocationProvider asks for it in onAppear below.
            UserAnnotation()
        }
        // Flat, no points of interest, no traffic: Apple's map should recede so our
        // pins read as the brightest thing on screen.
        .mapStyle(.standard(elevation: .flat,
                            pointsOfInterest: .excludingAll,
                            showsTraffic: false))
        .mapControls {
            MapCompass()
        }
        .overlay(alignment: .bottomTrailing) {
            recenterControls
        }
        .onAppear { location.request() }
        .overlay(alignment: .top) {
            if location.isDenied {
                Text("Turn on location in Settings to see where you are.")
                    .font(Theme.Font.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 70)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Map controls

extension MapScreen {

    /// Two separate buttons, because "where am I" and "show me everything" are
    /// different intentions and collapsing them into one toggle means the user
    /// has to guess which state it is in.
    fileprivate var recenterControls: some View {
        VStack(spacing: 10) {
            mapButton(
                symbol: "location.fill",
                label: "Centre on me",
                tint: location.isAuthorized ? Theme.maroon : Theme.ended
            ) {
                guard location.isAuthorized else {
                    location.request()
                    return
                }
                withAnimation(.easeInOut(duration: 0.4)) {
                    // Falls back to campus if the device has no fix yet, so the
                    // button never leaves the user staring at a blank map.
                    camera = .userLocation(fallback: .region(MapScreen.campusRegion))
                }
            }

            mapButton(
                symbol: "building.columns.fill",
                label: "Show all of campus",
                tint: Theme.maroon
            ) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    camera = .region(MapScreen.campusRegion)
                }
            }
        }
        .padding(.trailing, Theme.screenPadding)
        .padding(.bottom, 24)
    }

    /// CUSTOM VIEW: one circular map control. Built once and reused so both
    /// buttons stay identical in size, shadow and hit area.
    fileprivate func mapButton(
        symbol: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)   // HIG minimum tap target
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Pin

/// CUSTOM VIEW: one map pin. Broken out so the map body stays readable and so
/// the same pin can be reused in a preview.
struct EventPin: View {
    let event: Event
    let isPriority: Bool

    private var state: EventTimeState { event.timeState() }

    var body: some View {
        ZStack {
            Circle()
                .fill(state.color)
                .frame(width: isPriority ? 40 : 32,
                       height: isPriority ? 40 : 32)
                .overlay(
                    Circle()
                        .strokeBorder(isPriority ? Theme.burntOrange : .white,
                                      lineWidth: isPriority ? 3 : 2)
                )
                .shadow(radius: 3, y: 2)

            Image(systemName: event.tag.symbolName)
                .font(.system(size: isPriority ? 17 : 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        // A live event gently pulses so it reads as "right now" at a glance.
        .scaleEffect(state == .live ? 1.08 : 1.0)
        .animation(
            state == .live
                ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                : .default,
            value: state
        )
        .accessibilityLabel("\(event.title), \(state.label)")
    }
}
