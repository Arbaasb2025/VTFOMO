//
//  SignUpView.swift
//  VT FOMO
//
//  Account creation. The password rules are shown as a live checklist rather
//  than as an error after submitting - the user can see what is still missing
//  while they type, which is one of the 8 golden rules (offer informative
//  feedback, and prevent the error instead of reporting it).
//

import SwiftUI
import SwiftData

struct SignUpView: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?

    private var emailLooksValid: Bool {
        email.isEmpty || Validation.isValidVTEmail(email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your name") {
                    TextField("First and last name", text: $displayName)
                        .textContentType(.name)
                }

                Section {
                    TextField("netid@vt.edu", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("VT email")
                } footer: {
                    if !emailLooksValid {
                        Text("Has to end in @vt.edu.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Only Virginia Tech addresses can create an account.")
                    }
                }

                Section("Password") {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    // FUNCTIONAL: map each rule to a row, evaluating its
                    // closure against the current password.
                    ForEach(Validation.passwordRules, id: \.label) { rule in
                        let passed = rule.test(password)
                        Label {
                            Text(rule.label)
                                .font(.footnote)
                                .foregroundStyle(passed ? .secondary : .primary)
                        } icon: {
                            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(passed ? Theme.green : .secondary)
                        }
                    }
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Create Account", action: attemptSignUp)
                        .frame(maxWidth: .infinity)
                        .disabled(!formIsComplete)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var formIsComplete: Bool {
        Validation.isValidVTEmail(email)
            && Validation.isValidPassword(password)
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func attemptSignUp() {
        errorText = nil
        do {
            try auth.signUp(email: email,
                            password: password,
                            displayName: displayName,
                            context: context)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
