import SwiftUI

struct EventRow: View {
    let event: Event
    var isPriority: Bool = false
    var showSaveCount: Bool = false
    private var state: EventTimeState { event.timeState() }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 2) {
                Text(event.startTime, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 10, weight: .bold)).textCase(.uppercase)
                Text(event.startTime, format: .dateTime.day())
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Theme.maroon)
            .frame(width: 52, height: 60)
            .background(Theme.maroon.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: event.tag.symbolName)
                    Text(event.tag.displayName)
                    if isPriority {
                        Text("· Your hall").foregroundStyle(Theme.burntOrange)
                    }
                }
                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                Text(event.title).font(.headline).lineLimit(2)
                    .foregroundStyle(.primary)
                Text(event.startTime, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(event.locationName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    if state == .live {
                        Label("Live now", systemImage: "circle.fill")
                            .foregroundStyle(Theme.live)
                    } else if state == .soon {
                        Text("Starting soon").foregroundStyle(Theme.burntOrange)
                    }
                    if event.visibility == .hallOnly {
                        Label("Hall only", systemImage: "lock.fill")
                    }
                    if showSaveCount {
                        Label("\(event.saveCount)", systemImage: "bookmark.fill")
                    }
                }
                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .opacity(state == .past ? 0.55 : 1)
    }
}
