import Foundation

/// Explicitly provisioned local accounts only. Self-registration never assigns
/// the admin role. Populate this list only with the project owner's approved
/// email addresses, then provision the existing, verified account separately.
/// A production backend must verify email ownership and enforce all roles.
enum AdminAccess {
    static let allowedEmails: Set<String> = ["arbaasb@gmail.com"]

    static func permits(email: String, storedRole: String,
                        allowedEmails: Set<String> = allowedEmails) -> Bool {
        storedRole == UserRole.admin.rawValue &&
        allowedEmails.contains(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
