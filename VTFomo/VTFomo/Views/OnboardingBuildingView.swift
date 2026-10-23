//
//  OnboardingBuildingView.swift
//  VT FOMO
//
//  First-launch flow: pick your residence hall. This is what makes the map
//  personal - once a hall is chosen, that hall's events get highlighted and
//  sorted to the top, and hall-only events become visible.
//
//  Halls are grouped by residential area so a long flat list does not appear.
//

import SwiftUI
import SwiftData

struct OnboardingBuildingView: View {

    @Environment(\.modelContext) private var context
    let user: AppUser

    @Query(sort: \Building.name) private var buildings: [Building]

    @State private var selectedID: String?
    @State private var searchText = ""

    /// Halls grouped by area, filtered by the search field.
    /// FUNCTIONAL: filter then Dictionary(grouping:) then a sorted map.
    private var grouped: [(area: String, halls: [Building])] {
        let matching = buildings.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: matching, by: \.area)
            .map { (area: $0.key, halls: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.area < $1.area }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                intro

                List {
                    ForEach(grouped, id: \.area) { group in
                        Section(group.area) {
                            ForEach(group.halls) { hall in
                                row(for: hall)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search halls")

                Button("Continue", action: saveSelection)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.maroon)
                    .disabled(selectedID == nil)
                    .padding()
            }
            .background(Theme.background)
            .navigationTitle("Pick your hall")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var intro: some View {
        VStack(spacing: 6) {
            Text("Where do you live?")
                .font(.title2.bold())
            Text("Your hall's events get pinned to the top, and you'll see events meant only for residents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    /// CUSTOM VIEW: one selectable hall row.
    private func row(for hall: Building) -> some View {
        Button {
            selectedID = hall.id
        } label: {
            HStack {
                Text(hall.name)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedID == hall.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.maroon)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func saveSelection() {
        guard let selectedID,
              let hall = buildings.first(where: { $0.id == selectedID }) else { return }
        user.homeBuilding = hall
        try? context.save()
    }
}
