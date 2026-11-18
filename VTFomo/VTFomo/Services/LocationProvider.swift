//
//  LocationProvider.swift
//  VT FOMO
//
//  Owns the app's shared location fix and authorization state.
//
//  SwiftUI's map and event directions otherwise create independent Core
//  Location sessions. Sharing the latest fix prevents the event detail screen
//  from having to locate the same user again after the map already found them.
//
//  Requires NSLocationWhenInUseUsageDescription in the target's Info tab.
//  Without that key iOS silently ignores the request and the blue dot never
//  appears, with no error to tell you why.
//

import Foundation
import CoreLocation

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    static let shared = LocationProvider()

    private(set) var status: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?

    private let manager = CLLocationManager()
    private var updatesTask: Task<Void, Never>?

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// True once the user has said yes and the blue dot can be drawn.
    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// True when the user actively declined, which is the only case worth
    /// explaining on screen. "Not yet asked" needs no explanation.
    var isDenied: Bool {
        status == .denied || status == .restricted
    }

    /// Requests permission when needed, otherwise refreshes the shared fix.
    func request() {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLiveUpdates()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if isAuthorized {
            startLiveUpdates()
        }
    }

    private func startLiveUpdates() {
        guard updatesTask == nil else { return }

        updatesTask = Task { @MainActor [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard let self else { return }

                    if let location = update.location, location.horizontalAccuracy >= 0 {
                        self.lastLocation = location
                        self.updatesTask = nil
                        return
                    }

                    if update.authorizationDenied {
                        self.status = .denied
                        self.updatesTask = nil
                        return
                    }
                }
            } catch {
                self?.updatesTask = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocation = location
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // locationUnknown is transient. Keeping the previous valid fix lets
        // directions continue to work while Core Location tries again later.
        if (error as? CLError)?.code != .locationUnknown {
            manager.stopUpdatingLocation()
        }
    }
}
