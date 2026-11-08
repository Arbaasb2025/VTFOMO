//
//  Validation.swift
//  VT FOMO
//
//  PARADIGM NOTE — PROCEDURAL.
//  These are plain stateless functions grouped in an enum used as a namespace.
//  No instances, no stored state: input goes in, a result comes out. They are
//  called from the sign-up screen and from the event editor.
//

import Foundation

enum Validation {

    /// Requirement NFR-1: only Virginia Tech addresses may register.
    static func isValidVTEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasSuffix("@vt.edu") else { return false }
        let localPart = trimmed.dropLast("@vt.edu".count)
        guard !localPart.isEmpty else { return false }
        // Local part: letters, digits, dots, hyphens, underscores.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return localPart.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Every rule a password must satisfy, with the message shown when it fails.
    /// Keeping them in one array means the UI can show a live checklist rather
    /// than a single vague "password invalid" error.
    static let passwordRules: [(label: String, test: (String) -> Bool)] = [
        ("At least 8 characters", { $0.count >= 8 }),
        ("One uppercase letter",  { $0.contains(where: \.isUppercase) }),
        ("One lowercase letter",  { $0.contains(where: \.isLowercase) }),
        ("One number",            { $0.contains(where: \.isNumber) })
    ]

    /// Which rules a candidate password currently fails.
    static func failedPasswordRules(for password: String) -> [String] {
        passwordRules
            .filter { !$0.test(password) }
            .map(\.label)
    }

    static func isValidPassword(_ password: String) -> Bool {
        failedPasswordRules(for: password).isEmpty
    }

    /// An event needs a title and a sane time window.
    /// Returns nil when valid, or a message explaining the problem.
    static func eventProblem(title: String, start: Date, end: Date) -> String? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            return "Give your event a title."
        }
        if cleanTitle.count > 80 {
            return "Titles are limited to 80 characters."
        }
        if end <= start {
            return "The end time has to be after the start time."
        }
        if end.timeIntervalSince(start) > 60 * 60 * 24 {
            return "Events longer than 24 hours aren't supported yet."
        }
        return nil
    }

    /// Distance in metres between two coordinates, used for the "x min walk"
    /// label on the event detail screen.
    static func walkingMinutes(meters: Double) -> Int {
        let metersPerMinute = 80.0 // roughly a 3 mph walk
        return max(1, Int((meters / metersPerMinute).rounded()))
    }
}
