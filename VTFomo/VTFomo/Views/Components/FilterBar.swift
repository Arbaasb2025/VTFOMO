//
//  FilterBar.swift
//  VT FOMO
//
//  Horizontal row of filter chips that sits above the map and the list.
//  Tapping a chip toggles it; the bound FilterOptions drives both screens, so
//  a filter set on the map is still applied when you switch to the list.
//

import SwiftUI

struct FilterBar: View {

    @Binding var options: FilterOptions
    let counts: [EventTag: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {

                chip(title: "My Hall",
                     symbol: "house.fill",
                     isOn: options.onlyMyHall) {
                    options.onlyMyHall.toggle()
                }

                chip(title: "Saved",
                     symbol: "bookmark.fill",
                     isOn: options.onlySaved) {
                    options.onlySaved.toggle()
                }

                chip(title: "Today",
                     symbol: "clock.fill",
                     isOn: options.dayWindow == 1) {
                    options.dayWindow = options.dayWindow == 1 ? 7 : 1
                }

                Divider().frame(height: 22)

                ForEach(EventTag.allCases) { tag in
                    chip(title: tag.displayName,
                         symbol: tag.symbolName,
                         isOn: options.tags.contains(tag),
                         badge: counts[tag]) {
                        // Set arithmetic, not an if/else ladder.
                        if options.tags.contains(tag) {
                            options.tags.remove(tag)
                        } else {
                            options.tags.insert(tag)
                        }
                    }
                }

                if options.isActive {
                    Button {
                        options = FilterOptions()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.footnote.weight(.medium))
                    }
                    .tint(Theme.maroon)
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    /// CUSTOM VIEW: one chip. Written as a function rather than a separate
    /// struct because it needs no state of its own.
    private func chip(title: String,
                      symbol: String,
                      isOn: Bool,
                      badge: Int? = nil,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2)
                Text(title)
                    .font(.footnote.weight(.medium))
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isOn ? Color.white.opacity(0.28) : Theme.maroon.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn ? Theme.maroon : Theme.card)
            .foregroundStyle(isOn ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
