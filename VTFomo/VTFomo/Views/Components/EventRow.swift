//
//  EventRow.swift
//  VT FOMO
//
//  One event as it appears in a list. Used by the events list, the saved list,
//  and the organizer dashboard, so all three stay visually consistent.
//

import SwiftUI

struct EventRow: View {

    let event: Event
    /// Draws the orange "Your Hall" marker when true.
    var isPriority: Bool = false
    var showSaveCount: Bool = false

    private var state: EventTimeState { event.timeState() }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Colour bar carrying the time state, plus the tag icon.
            VStack(spacing: 6) {
                Image(systemName: event.tag.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(state.color)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {

                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)
                    if isPriority {
                        Text("YOUR HALL")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.burntOrange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                Text(Theme.rangeText(from: event.startTime, to: event.endTime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(event.locationName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if state == .live {
                        Label("Happening now", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.green)
                    } else if state == .soon {
                        Label("Starting soon", systemImage: "clock.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.orange)
                    }

                    if event.visibility == .hallOnly {
                        Label("Hall only", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if showSaveCount {
                        Label("\(event.saveCount)", systemImage: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .opacity(state == .past ? 0.55 : 1.0)
    }
}
