//
//  LoginView.swift
//  VT FOMO
//
//  Email + password sign-in, with Face ID as a shortcut for returning users.
//

import SwiftUI
import SwiftData

struct LoginView: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    // DATA BINDING: @State here, $bound into the TextFields below. Typing
    // updates the state, which re-renders the view and re-enables the button.
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var showingSignUp = false
    @State private var isBusy = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isBusy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    header

                    VStack(spacing: 14) {
                        TextField("VT email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: attemptLogin) {
                        if isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In").frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.maroon)
                    .disabled(!canSubmit)

                    if auth.biometricsAvailable {
                        Button {
                            Task { _ = await auth.unlockWithBiometrics(context: context) }
                        } label: {
                            Label(
                                auth.rememberedDisplayName(context: context)
                                    .map { "Log in as \($0)" } ?? "Log in with Face ID",
                                systemImage: "faceid"
                            )
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(Theme.maroon)
                    }

                    Button("New here? Create an account") { showingSignUp = true }
                        .font(.footnote)
                        .tint(Theme.maroon)

                    demoHint
                }
                .padding(20)
                .frame(maxWidth: 520) // keeps the form readable on iPad
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Theme.maroon)
            Text("VT FOMO")
                .font(.largeTitle.bold())
            Text("Every event on campus, on one map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 8)
    }

    /// Demo credentials so a grader can get in without reading the README.
    /// Remove this block before any real deployment.
    private var demoHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Demo accounts").font(.caption.bold())
            Text("Organizer — emmac@vt.edu").font(.caption2)
            Text("Student — robertk@vt.edu").font(.caption2)
            Text("Password — \(SampleData.demoPassword)").font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.top, 20)
    }

    // MARK: - Actions

    private func attemptLogin() {
        isBusy = true
        errorText = nil
        do {
            try auth.logIn(email: email, password: password, context: context)
        } catch {
            errorText = error.localizedDescription
        }
        isBusy = false
    }
}
