//
//  CampusSheet.swift
//  VT FOMO
//
//  The draggable panel that sits over the campus map.
//
//  Why this exists: a full-screen map is Apple's design, not ours, and it
//  buries the thing people actually came for. Events only appeared after a
//  tap on a pin, which made the app read as a map with markers rather than a
//  way to find something to do tonight. This sheet flips it - the map becomes
//  context, the events become the content, and the first thing anyone sees on
//  opening the app is what is happening right now.
//
//  Three resting positions: peek (just the live count), half, and full.
//

import SwiftUI

struct CampusSheet: View {

    enum Detent: CaseIterable {
        case peek, half, full

        /// Height as a fraction of the space available.
        var fraction: CGFloat {
            switch self {
            case .peek: return 0.30
            case .half: return 0.52
            case .full: return 0.92
            }
        }
    }

    let events: [Event]
    let user: AppUser
    @Binding var selectedEvent: Event?
    @Binding var detent: Detent

    @State private var dragOffset: CGFloat = 0
    @State private var pulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Grouping
    //
    // PARADIGM NOTE - FUNCTIONAL: the whole pipeline is filter and sort with no
    // mutable bookkeeping, so the groups recompute correctly whenever the
    // events or the clock change.

    private var live: [Event] {
        events.filter { $0.timeState() == .live }
    }

    private var soon: [Event] {
        events.filter { $0.timeState() == .soon }
            .sorted { $0.startTime < $1.startTime }
    }

    private var later: [Event] {
        events.filter { $0.timeState() == .upcoming }
            .sorted { $0.startTime < $1.startTime }
    }

    /// The headline. This is the line that has to earn the app's name.
    private var headline: String {
        if !live.isEmpty {
            return live.count == 1 ? "1 happening right now" : "\(live.count) happening right now"
        }
        if let next = soon.first ?? later.first {
            return "Next up \(Theme.countdown(to: next.startTime))"
        }
        return "Nothing scheduled yet"
    }

    private var subhead: String {
        if !live.isEmpty { return "Go now, or miss it." }
        if let next = soon.first ?? later.first { return next.title }
        return "Check back later, or post something yourself."
    }

    /// How much of the sheet the floating tab bar covers. The sheet's content
    /// starts below this so the headline is never hidden behind the buttons.
    private let tabBarClearance: CGFloat = 76

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height * detent.fraction
            let offset = max(0, dragOffset)

            VStack(spacing: 0) {
                grabber
                header
                Divider().padding(.top, 10)
                list
            }
            .frame(width: geo.size.width, height: height + tabBarClearance, alignment: .top)
            .background(.regularMaterial)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 22,
                style: .continuous
            ))
            .shadow(color: .black.opacity(0.16), radius: 14, y: -3)
            .offset(y: geo.size.height - height + offset)
            .gesture(drag(in: geo.size.height))
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: detent)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
    }

    // MARK: - Pieces

    private var grabber: some View {
        Capsule()
            .fill(Theme.hairline)
            .frame(width: 38, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { cycleDetent() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {

            // A live dot that actually pulses. The one piece of ambient motion
            // in the app, and only when something is genuinely happening.
            if !live.isEmpty {
                Circle()
                    .fill(Theme.live)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.35 : 1.0)
                    .opacity(pulse ? 0.55 : 1.0)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(Theme.Font.numeric(19, weight: .bold))
                Text(subhead)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(events.count)")
                .font(Theme.Font.numeric(13))
                .chipStyle(tint: Theme.maroon)
        }
        .padding(.horizontal, Theme.screenPadding)
        .contentShape(Rectangle())
        .onTapGesture { cycleDetent() }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to expand the list of events")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                section("Happening now", live)
                section("Starting soon", soon)
                section("Later", later)

                if events.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, tabBarClearance + 24)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Event]) -> some View {
        if !items.isEmpty {
            HStack {
                Text(title)
                    .font(Theme.Font.micro)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 4)

            ForEach(items) { event in
                Button {
                    selectedEvent = event
                } label: {
                    EventRow(event: event, isPriority: event.isPriority(for: user))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No events match these filters.")
                .font(Theme.Font.body)
            Text("Try turning one off.")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Interaction

    private func drag(in available: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Resist upward drags past full, so it never rubber-bands off
                // the top of the screen.
                dragOffset = value.translation.height < 0
                    ? value.translation.height / 3
                    : value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    detent = nextDetent(for: velocity)
                    dragOffset = 0
                }
            }
    }

    /// Chooses the resting position from the flick direction. A short flick
    /// moves one step rather than jumping the whole way, which is what makes
    /// the sheet feel like it is being handled rather than teleporting.
    private func nextDetent(for velocity: CGFloat) -> Detent {
        let goingDown = velocity > 60
        let goingUp = velocity < -60

        switch (detent, goingUp, goingDown) {
        case (.peek, true, _):  return .half
        case (.half, true, _):  return .full
        case (.full, _, true):  return .half
        case (.half, _, true):  return .peek
        default:                return detent
        }
    }

    private func cycleDetent() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            detent = detent == .full ? .peek : (detent == .peek ? .half : .full)
        }
    }
}
