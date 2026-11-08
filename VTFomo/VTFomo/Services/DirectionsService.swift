//
//  DirectionsService.swift
//  VT FOMO
//
//  Walking directions from wherever you are to an event.
//
//  Two jobs:
//    1. Work out how far away the event is and how long the walk takes, so the
//       UI can say "7 min walk" instead of printing an address nobody reads.
//    2. Hand the route off to Apple Maps for actual turn-by-turn, which is the
//       right call - rebuilding navigation inside a class project would be a
//       month of work to end up worse than the app already

import Foundation
import MapKit
import CoreLocation

@Observable
final class DirectionsService: NSObject, CLLocationManagerDelegate {

    // MARK: - State

    enum RouteState: Equatable {
        case idle
        case needsPermission
        case locating
        case ready(minutes: Int, metres: Double)
        case unavailable(String)
    }

    private(set) var state: RouteState = .idle
    /// The drawn route, handed to the Map so it can show the walking line.
    private(set) var route: MKRoute?

    private let manager = CLLocationManager()
    private var destination: CLLocationCoordinate2D?
    private var hasRequestedFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public

    /// Ask for a walking route to `coordinate`. Safe to call repeatedly.
    func route(to coordinate: CLLocationCoordinate2D) {
        destination = coordinate

        switch manager.authorizationStatus {
        case .notDetermined:
            state = .needsPermission
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .unavailable("Turn on location in Settings to see the walk.")
        case .authorizedWhenInUse, .authorizedAlways:
            beginLocating()
        @unknown default:
            state = .unavailable("Location is not available.")
        }
    }

    /// Opens the walk in Apple Maps. `name` becomes the pin label.
    func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    func reset() {
        state = .idle
        route = nil
        hasRequestedFix = false
    }

    // MARK: - Private

    private func beginLocating() {
        state = .locating
        hasRequestedFix = true
        manager.requestLocation()
    }

    /// Asks MapKit for a walking route and keeps the fastest one.
    private func calculate(from origin: CLLocationCoordinate2D) {
        guard let destination else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        Task { @MainActor in
            do {
                let response = try await MKDirections(request: request).calculate()

                // PARADIGM NOTE - FUNCTIONAL: pick the shortest route with
                // min(by:) rather than looping and tracking a running best.
                guard let best = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
                    state = .unavailable("No walking route found.")
                    return
                }

                route = best
                state = .ready(
                    minutes: max(1, Int((best.expectedTravelTime / 60).rounded())),
                    metres: best.distance
                )
            } catch {
                // Straight-line fallback so the UI still says something useful
                // when the routing server is unreachable.
                let metres = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                    .distance(from: CLLocation(latitude: destination.latitude,
                                               longitude: destination.longitude))
                state = .ready(minutes: max(1, Int((metres / 84).rounded())), metres: metres)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        calculate(from: fix.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        state = .unavailable("Couldn't work out where you are.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Fires right after the user taps Allow on the permission sheet.
            if !hasRequestedFix { beginLocating() }
        case .denied, .restricted:
            state = .unavailable("Turn on location in Settings to see the walk.")
        default:
            break
        }
    }
}

// MARK: - Formatting

extension DirectionsService.RouteState {

    /// Short line for the button, e.g. "7 min walk · 550 m".
    var summary: String? {
        guard case let .ready(minutes, metres) = self else { return nil }
        let distance = metres < 1000
            ? "\(Int(metres.rounded())) m"
            : String(format: "%.1f km", metres / 1000)
        return "\(minutes) min walk · \(distance)"
    }
}
