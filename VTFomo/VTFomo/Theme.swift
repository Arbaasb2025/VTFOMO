//
//  Theme.swift
//  VT FOMO
//
//  The design system. Every colour, type size, radius and formatter lives
//  here, so the app stays harmonious and a change in one place moves the
//  whole product (HIG: harmony and consistency).
//
//  The idea behind the look: Virginia Tech's own maroon and burnt orange do
//  all the identity work, the layout stays quiet and Apple-native, and the
//  personality shows up in motion rather than decoration. That way the app
//  reads as ours without getting cluttered.
//

import SwiftUI

enum Theme {

    // MARK: - Colour
    //
    // Maroon and burnt orange are Virginia Tech's official pair. Everything
    // else is a neutral tuned to sit beside them - the greys carry a little
    // maroon so they feel related rather than borrowed from a system palette.

    /// Builds a colour that changes with light and dark mode.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Chicago Maroon. The primary brand colour.
    static let maroon = Color(red: 0.525, green: 0.122, blue: 0.255)   // #861F41
    /// Burnt Orange. Used for emphasis and for the user's own hall.
    static let burntOrange = Color(red: 0.898, green: 0.459, blue: 0.122) // #E5751F

    /// Lighter maroon for text on dark surfaces, where full maroon goes muddy.
    static let maroonLight = Color(red: 0.788, green: 0.318, blue: 0.451)

    // Semantic states. Named for what they mean, not what they look like, so
    // swapping the hue later doesn't require touching every call site.
    static let live    = Color(red: 0.133, green: 0.616, blue: 0.333)
    static let soon    = burntOrange
    static let later   = maroon
    static let ended   = Color(white: 0.58)

    // Surfaces
    static let background = adaptive(
        light: UIColor(red: 0.965, green: 0.957, blue: 0.960, alpha: 1),
        dark:  UIColor(red: 0.071, green: 0.055, blue: 0.063, alpha: 1)
    )
    static let card = adaptive(
        light: UIColor.white,
        dark:  UIColor(red: 0.118, green: 0.094, blue: 0.106, alpha: 1)
    )
    static let hairline = adaptive(
        light: UIColor(red: 0.886, green: 0.867, blue: 0.875, alpha: 1),
        dark:  UIColor(red: 0.200, green: 0.169, blue: 0.184, alpha: 1)
    )

    // Legacy names kept so older screens keep compiling.
    static let orange = burntOrange
    static let green  = live
    static let gray   = ended

    // MARK: - Type
    //
    // One family (SF Pro) at two widths. The rounded width is reserved for
    // numbers and the wordmark - countdowns, counts, streaks - which gives the
    // app a little warmth without making body text look like a children's toy.

    enum Font {
        /// The wordmark and the biggest numbers.
        static func display(_ size: CGFloat = 34) -> SwiftUI.Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }
        /// Numerals that should feel friendly: "7 min walk", "3 live now".
        static func numeric(_ size: CGFloat = 17, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static let screenTitle  = SwiftUI.Font.system(size: 22, weight: .bold)
        static let sectionTitle = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body         = SwiftUI.Font.system(size: 16)
        static let caption      = SwiftUI.Font.system(size: 13)
        /// Small emphatic labels. Sentence case, never all caps.
        static let micro        = SwiftUI.Font.system(size: 11, weight: .semibold)
    }

    // MARK: - Layout
    //
    // Radius encodes hierarchy rather than being one value on everything:
    // bigger surfaces get a bigger curve, small controls stay tight.

    static let cardRadius: CGFloat  = 16
    static let tileRadius: CGFloat  = 12
    static let chipRadius: CGFloat  = 8
    static let corner: CGFloat      = cardRadius   // legacy alias

    static let spacing: CGFloat     = 12
    static let cardPadding: CGFloat = 14
    static let screenPadding: CGFloat = 16
    /// Body text stops here so lines never run past a comfortable measure.
    static let readableWidth: CGFloat = 700

    // MARK: - Formatters
    // Built once and reused. DateFormatter is expensive to construct, and
    // making one inside a SwiftUI body rebuilds it on every redraw.

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    /// "Fri, Sep 18 · 7:00 PM – 9:00 PM"
    static func rangeText(from start: Date, to end: Date) -> String {
        let day = dayFormatter.string(from: start)
        let s = timeFormatter.string(from: start)
        let e = timeFormatter.string(from: end)
        return "\(day) · \(s) – \(e)"
    }

    /// "in 12 min", "in 3 h", "started 20 min ago". Short on purpose - this
    /// appears next to titles where space is tight.
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        let ago = seconds < 0
        let magnitude = abs(seconds)

        let text: String
        switch magnitude {
        case ..<60:    text = "less than a minute"
        case ..<3600:  text = "\(magnitude / 60) min"
        case ..<86400: text = "\(magnitude / 3600) h"
        default:       text = "\(magnitude / 86400) d"
        }
        return ago ? "started \(text) ago" : "in \(text)"
    }
}

// MARK: - Reusable modifiers

/// The standard card surface: used by event rows and detail sections.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

/// Small pill label, e.g. a tag or a state badge.
struct ChipStyle: ViewModifier {
    var tint: Color
    func body(content: Content) -> some View {
        content
            .font(Theme.Font.micro)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func chipStyle(tint: Color) -> some View { modifier(ChipStyle(tint: tint)) }

    /// Constrains body content to a comfortable reading width and centres it,
    /// which is what makes the iPad layout not look like a stretched phone.
    func readableColumn() -> some View {
        frame(maxWidth: Theme.readableWidth).frame(maxWidth: .infinity)
    }
}
