import Foundation
import LocalAuthentication

/// Allows authentication outcomes to be tested without a physical Face ID scan.
protocol BiometricAuthenticating {
    var isAvailable: Bool { get }
    var name: String { get }
    var symbol: String { get }
    func authenticate() async throws -> Bool
}

struct SystemBiometricAuthenticator: BiometricAuthenticating {
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    private var type: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    var name: String { type == .touchID ? "Touch ID" : "Face ID" }
    var symbol: String { type == .touchID ? "touchid" : "faceid" }

    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                localizedReason: "Log back in to VT FOMO")
    }
}
