//
//  Building.swift
//  VT FOMO
//
//  A residence hall on campus. Students pick one of these during onboarding,
//  and organizers can restrict an event so only certain halls can see it.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Building {


    @Attribute(.unique) var id: String
    var name: String

    var area: String
    var latitude: Double
    var longitude: Double

    @Relationship(deleteRule: .nullify, inverse: \AppUser.homeBuilding)
    var residents: [AppUser] = []

    // MARK: - Init

    init(id: String, name: String, area: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.area = area
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: - Computed


    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
