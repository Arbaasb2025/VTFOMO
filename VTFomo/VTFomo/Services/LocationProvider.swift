//
//  LocationProvider.swift
//  VT FOMO
//
//  Asks for location permission and reports what the answer was.
//
//  Deliberately small. The map does not need coordinates from us - SwiftUI's
//  `UserAnnotation` and `MapCameraPosition.userLocation` read the device
//  location themselves once permission exists. All this type does is make sure
//  permission gets asked for, and give the UI something to check so it can
//  explain itself when the answer was no.
//
//  Requires NSLocationWhenInUseUsageDescription in the target's Info tab.
//  Without that key iOS silently ignores the request and the blue dot never
//  appears, with no error to tell you why.
//

import Foundation
import CoreLocation

@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private(set) var status: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
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

    /// Asks once. Calling it again after an answer is a no-op, so it is safe
    /// to call from onAppear every time the map shows.
    func request() {
        guard status == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
