//
//  LaunchView.swift
//  VT FOMO
//
//  The first thing anyone sees. The Drillfield draws itself, three pins drop
//  onto it, and the wordmark sets underneath.
//
//  This is the one place in the app that is deliberately loud. Everything else
//  stays quiet and Apple-native, so the personality has somewhere to live
//  without the whole product getting busy. The whole sequence is about 1.6s -
//  long enough to land, short enough that it never becomes the thing standing
//  between someone and the event they are late for.
//
//  Accessibility: the entire animation is skipped when Reduce Motion is on,
//  and the screen still shows its final state.
//

import SwiftUI

struct LaunchView: View {

    /// Set to true by the parent once real work has finished.
    var isFinished: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fieldProgress: CGFloat = 0
    @State private var pinsLanded = 0
    @State private var wordmarkIn = false
    @State private var glowIn = false

    /// Where the three pins land, in unit coordinates over the field.
    private let pinSpots: [CGPoint] = [
        CGPoint(x: 0.28, y: 0.42),
        CGPoint(x: 0.63, y: 0.30),
        CGPoint(x: 0.50, y: 0.63)
    ]

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 28) {
                Spacer()
                field
                    .frame(width: 220, height: 150)
                wordmark
                Spacer()
                footer
            }
            .padding(Theme.screenPadding)
        }
        .onAppear(perform: run)
    }

    // MARK: - Pieces

    /// A soft maroon-to-orange wash, brightest behind the field. Static - the
    /// motion in this screen comes from the drawing, not the background.
    private var backdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.maroon.opacity(glowIn ? 0.22 : 0.0),
                         Theme.burntOrange.opacity(glowIn ? 0.10 : 0.0),
                         .clear],
                center: .center,
                startRadius: 10,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    /// The Drillfield oval plus its paths, drawn on with a trim animation.
    private var field: some View {
        GeometryReader { geo in
            ZStack {
                DrillfieldShape()
                    .trim(from: 0, to: fieldProgress)
                    .stroke(
                        LinearGradient(colors: [Theme.maroon, Theme.burntOrange],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                WalkwaysShape()
                    .trim(from: 0, to: fieldProgress)
                    .stroke(Theme.maroon.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                // Pins drop in one after another once the field is drawn.
                ForEach(Array(pinSpots.enumerated()), id: \.offset) { index, spot in
                    DropPin(tint: index == 1 ? Theme.burntOrange : Theme.maroon)
                        .position(x: spot.x * geo.size.width,
                                  y: spot.y * geo.size.height)
                        .opacity(pinsLanded > index ? 1 : 0)
                        .offset(y: pinsLanded > index ? 0 : -26)
                        .scaleEffect(pinsLanded > index ? 1 : 0.6, anchor: .bottom)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var wordmark: some View {
        VStack(spacing: 6) {
            Text("VT FOMO")
                .font(Theme.Font.display(40))
                .tracking(1.5)
                .foregroundStyle(
                    LinearGradient(colors: [Theme.maroon, Theme.burntOrange],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )

            Text("Every event on campus, on one map.")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(wordmarkIn ? 1 : 0)
        .offset(y: wordmarkIn ? 0 : 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VT FOMO. Every event on campus, on one map.")
    }

    /// A quiet progress line rather than a spinner. It tells the user work is
    /// happening without competing with the animation above it.
    private var footer: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Theme.hairline)
                .frame(width: 120, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.burntOrange)
                        .frame(width: isFinished ? 120 : 44, height: 3)
                        .animation(.easeInOut(duration: 0.4), value: isFinished)
                }

            Text(isFinished ? "Ready" : "Finding what's happening")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .opacity(wordmarkIn ? 1 : 0)
        .padding(.bottom, 24)
    }

    // MARK: - Sequence

    private func run() {
        guard !reduceMotion else {
            // Same destination, no journey.
            fieldProgress = 1
            pinsLanded = pinSpots.count
            wordmarkIn = true
            glowIn = true
            return
        }

        withAnimation(.easeOut(duration: 0.8)) {
            glowIn = true
        }
        withAnimation(.easeInOut(duration: 0.9)) {
            fieldProgress = 1
        }

        // Pins land in sequence, each with its own little bounce.
        for index in pinSpots.indices {
            let delay = 0.75 + Double(index) * 0.13
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58).delay(delay)) {
                pinsLanded = index + 1
            }
        }

        withAnimation(.easeOut(duration: 0.45).delay(1.15)) {
            wordmarkIn = true
        }
    }
}

// MARK: - Shapes

/// The Drillfield: a wide oval, the shape every VT student pictures when they
/// picture campus.
private struct DrillfieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.06,
                                         dy: rect.height * 0.14))
        return path
    }
}

/// The paths cutting across the field.
private struct WalkwaysShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.30)
        )
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.22,
                              y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18,
                                 y: rect.maxY - rect.height * 0.18))
        return path
    }
}

/// A single map pin, matching the ones used on the real map so the launch
/// screen is a promise the app actually keeps.
private struct DropPin: View {
    var tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: tint.opacity(0.4), radius: 5, y: 3)

            Image(systemName: "mappin")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    LaunchView()
}
