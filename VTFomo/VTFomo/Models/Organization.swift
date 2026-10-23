//
//  Organization.swift
//  VT FOMO
//
//  A club, department, or other group that publishes events.
//  Organizers who are club officers belong to one of these; RAs and SLs
//  do not (their authority comes from their building instead).
//

import Foundation
import SwiftData

@Model
final class Organization {

    @Attribute(.unique) var id: String
    var name: String
    var abbreviation: String
    var summary: String

    /// Users who can post on behalf of this organization.
    @Relationship(deleteRule: .nullify, inverse: \AppUser.organization)
    var officers: [AppUser] = []

    init(id: String, name: String, abbreviation: String, summary: String) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.summary = summary
    }
}
