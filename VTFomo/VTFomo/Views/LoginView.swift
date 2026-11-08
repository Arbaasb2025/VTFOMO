import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthService.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var showingSignUp = false
    @State private var isBusy = false
    @State private var biometricsReady = false
    @State private var showingDemoAccounts = true
    @State private var showingHelp = false
    @State private var showingLogin = false
    @State private var slide = 0
    @State private var paused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scenes = ["CampusGolden", "CampusEvening"]
    private var slideshowRunning: Bool {
        scenePhase == .active && !paused && !reduceMotion && !showingLogin
    }
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty && !isBusy && !auth.isWorking
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backdrop(size: geometry.size)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 9) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title3.weight(.bold))
                            Text("VT FOMO").font(.headline).tracking(1)
                            Spacer()
                            Text("BLACKSBURG, VA")
                                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                        }
                        Spacer(minLength: 160)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Capsule().fill(Theme.burntOrange).frame(width: 24, height: 3)
                                Text(slide == 0 ? "A CAMPUS FULL OF POSSIBILITIES" : "GOOD NIGHTS START HERE")
                                    .font(.system(size: 10, weight: .bold)).tracking(1.6)
                            }
                            Text(slide == 0 ? "Go where\nthe good is." : "Your people.\nYour next plan.")
                                .font(.system(.largeTitle, design: .default, weight: .bold))
                                .tracking(-1.2)
                                .fixedSize(horizontal: false, vertical: true)
                                .id(slide)
                                .transition(.opacity)
                            Text("The plans, the people, the moments.\nFind them all around Tech.")
                                .font(.subheadline).lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.8))
                            slideshowControls
                        }
                        .padding(.bottom, 4)

                        VStack(spacing: 12) {
                            Button { showingLogin = true } label: {
                                HStack {
                                    Text("Get started").fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").fontWeight(.semibold)
                                }
                                .padding(20)
                                .foregroundStyle(Color(red: 0.18, green: 0.10, blue: 0.13))
                                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(WelcomePressStyle())
                            if auth.rememberedDisplayName(context: context) != nil && biometricsReady {
                                Button(action: attemptBiometrics) {
                                    Label("Welcome back · Use \(auth.biometricName)", systemImage: auth.biometricSymbol)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                                }
                                .buttonStyle(WelcomePressStyle())
                                .disabled(isBusy || auth.isWorking)
                            } else {
                                Button("Already part of it? Sign in") { showingLogin = true }
                                    .font(.subheadline).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                            }
                            if let errorText {
                                Text(errorText).font(.footnote).foregroundStyle(.white)
                                    .accessibilityIdentifier("loginError")
                            }
                        }
                    }
                    .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 24)
                    .frame(maxWidth: 520)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .arrival()
                }
                .scrollIndicators(.hidden)
                .foregroundStyle(.white)
            }
            .sheet(isPresented: $showingLogin) { signInSheet }
            .onAppear { refreshBiometrics() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshBiometrics() }
            }
            .task(id: slideshowRunning) {
                guard slideshowRunning else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(7)) }
                    catch { return }
                    guard !Task.isCancelled else { return }
                    selectSlide((slide + 1) % scenes.count)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func backdrop(size: CGSize) -> some View {
        ZStack {
            ForEach(scenes.indices, id: \.self) { index in
                Image(scenes[index])
                    .resizable().scaledToFill()
                    .frame(width: size.width, height: size.height + 100)
                    .clipped()
                    .opacity(slide == index ? 1 : 0)
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.25), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .black.opacity(0.4), location: 0.52),
                .init(color: Color(red: 0.07, green: 0.05, blue: 0.06).opacity(0.97), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var slideshowControls: some View {
        HStack(spacing: 4) {
            ForEach(scenes.indices, id: \.self) { index in
                Button { selectSlide(index) } label: {
                    Capsule().fill(.white.opacity(slide == index ? 1 : 0.35))
                        .frame(width: slide == index ? 30 : 8, height: 4)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(index == 0 ? "Show campus at golden hour" : "Show evening gathering")
                .accessibilityAddTraits(slide == index ? .isSelected : [])
            }
            Spacer()
            if !reduceMotion {
                Button { paused.toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.caption).frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(paused ? "Play slideshow" : "Pause slideshow")
            }
        }
        .buttonStyle(.plain)
    }

    private func selectSlide(_ index: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) { slide = index }
    }

    private var signInSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Good to see you.").font(.title.bold())
                        Text("Sign in to find your next plan.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    loginCard
                    if auth.rememberedDisplayName(context: context) != nil { biometricCard }
                    Button("Sign-in help & demo accounts") { showingHelp = true }
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Sign in").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showingLogin = false }
            } }
            .sheet(isPresented: $showingSignUp) { SignUpView() }
            .sheet(isPresented: $showingHelp) { helpSheet }
        }
        .tint(Theme.maroon)
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(biometricExplanation).font(.subheadline).foregroundStyle(.secondary)
                    Button("Check biometric availability", action: refreshBiometrics)
                    #if targetEnvironment(simulator)
                    Text("Simulator: choose Features → Face ID → Enrolled. Tap Use Face ID, then choose Features → Face ID → Matching Face.")
                        .font(.footnote).foregroundStyle(.secondary)
                    #endif
                    #if DEBUG
                    demoAccounts
                    #endif
                }.padding(24)
            }
            .background(Theme.background)
            .navigationTitle("Sign-in help").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { showingHelp = false }
            } }
        }.tint(Theme.maroon)
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email address").font(.caption.weight(.semibold))
                HStack(spacing: 12) {
                    Image(systemName: "envelope").foregroundStyle(Theme.maroon).accessibilityHidden(true)
                    TextField("you@vt.edu", text: $email)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next).onSubmit { focusedField = .password }
                        .accessibilityLabel("Email address")
                }
                .padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Password").font(.caption.weight(.semibold))
                HStack(spacing: 12) {
                    Image(systemName: "lock").foregroundStyle(Theme.maroon).accessibilityHidden(true)
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password).focused($focusedField, equals: .password)
                        .submitLabel(.go).onSubmit { if canSubmit { attemptLogin() } }
                        .accessibilityLabel("Password")
                }
                .padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
            }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("loginError")
            }
            Button(action: attemptLogin) {
                HStack {
                    Spacer()
                    if isBusy { ProgressView().tint(.white) }
                    else { Text("Log In").fontWeight(.semibold); Image(systemName: "arrow.right") }
                    Spacer()
                }.padding(.vertical, 7)
            }
            .buttonStyle(PressButtonStyle(prominent: true))
            .disabled(!canSubmit)
            Button("New here? Create an account") { showingSignUp = true }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                .padding(.vertical, 4).disabled(isBusy || auth.isWorking)
        }

    }

    private var biometricCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Rectangle().fill(Theme.hairline).frame(height: 1)
                Text("or").font(.caption).foregroundStyle(.secondary)
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            if let name = auth.rememberedDisplayName(context: context) {
                if biometricsReady {
                    Button(action: attemptBiometrics) {
                        Label("Use \(auth.biometricName)", systemImage: auth.biometricSymbol)
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("Use \(auth.biometricName) as \(name)")
                    .disabled(isBusy || auth.isWorking)
                } else {
                    Button("Check biometric availability", action: refreshBiometrics)
                        .font(.subheadline).disabled(isBusy || auth.isWorking)
                }
                Button("Forget \(name) on this device") {
                    auth.forgetDevice(); errorText = nil; refreshBiometrics()
                }
                .font(.caption).foregroundStyle(.secondary)
                .disabled(isBusy || auth.isWorking)
            }
        }
    }

    private var biometricExplanation: String {
        guard auth.rememberedDisplayName(context: context) != nil else {
            return "Log in with your password once to use Face ID or Touch ID on this device."
        }
        return biometricsReady
            ? "Your account is remembered. Confirm it's you with Apple's secure biometric prompt."
            : "Biometric login isn't available right now. Check enrollment and app permissions, or use your password."
    }

    #if DEBUG
    private var demoAccounts: some View {
        DisclosureGroup("Explore demo accounts", isExpanded: $showingDemoAccounts) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose an account to fill the sign-in form.").font(.footnote).foregroundStyle(.secondary)
                demoAccount("Administrator", email: "arbaasb@gmail.com", symbol: "shield.lefthalf.filled")
                demoAccount("Area Coordinator", email: "cord@vt.edu", symbol: "building.2")
                demoAccount("Authorized Organizer", email: "org@vt.edu", symbol: "checkmark.seal")
                demoAccount("Student Leader", email: "sl@vt.edu", symbol: "person.2.fill")
                demoAccount("Student", email: "stu@vt.edu", symbol: "graduationcap")
                Text("Demo password: \(SampleData.demoPassword). Organizers start pending approval. These accounts are local to this installation.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 12)
        }
        .font(.subheadline.weight(.semibold))
        .padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .disabled(isBusy || auth.isWorking)
    }

    private func demoAccount(_ title: String, email accountEmail: String, symbol: String) -> some View {
        Button {
            email = accountEmail; password = SampleData.demoPassword
            errorText = nil; focusedField = nil; showingHelp = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(accountEmail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.left").font(.caption)
            }.padding(.vertical, 7)
        }.buttonStyle(.plain).foregroundStyle(Theme.maroon)
    }
    #endif

    private func refreshBiometrics() { biometricsReady = auth.biometricsAvailable }

    private func attemptBiometrics() {
        guard !isBusy else { return }
        focusedField = nil; isBusy = true; errorText = nil
        Task {
            _ = await auth.unlockWithBiometrics(context: context)
            errorText = auth.errorMessage; isBusy = false; refreshBiometrics()
        }
    }

    private func attemptLogin() {
        guard canSubmit else { return }
        focusedField = nil; isBusy = true; errorText = nil
        do { try auth.logIn(email: email, password: password, context: context) }
        catch { errorText = error.localizedDescription }
        isBusy = false
    }
}

private struct WelcomePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
