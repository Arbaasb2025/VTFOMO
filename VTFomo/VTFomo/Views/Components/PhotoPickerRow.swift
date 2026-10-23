//
//  PhotoPickerRow.swift
//  VT FOMO
//
//  The "Photos" section of the event editor: a strip of thumbnails plus an add
//  button that opens the system photo picker.
//
//  CUSTOM VIEW. Kept separate from CreateEventView so the editor body stays
//  readable and so this can be reused later for the post-event photo wall.
//

import SwiftUI
import PhotosUI

struct PhotoPickerRow: View {

    /// File names, bound straight to the draft event's photo list.
    @Binding var photoNames: [String]
    var limit: Int = 6

    @State private var selection: [PhotosPickerItem] = []
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if photoNames.isEmpty && !isImporting {
                emptyState
            } else {
                thumbnails
            }

            PhotosPicker(
                selection: $selection,
                maxSelectionCount: limit - photoNames.count,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    photoNames.isEmpty ? "Add photos" : "Add more",
                    systemImage: "photo.badge.plus"
                )
                .font(.subheadline.weight(.medium))
            }
            .disabled(photoNames.count >= limit)

            if photoNames.count >= limit {
                Text("That's the maximum of \(limit) photos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
    }

    // MARK: - Pieces

    private var emptyState: some View {
        // An empty state is an invitation to act, not an apology for being empty.
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(Theme.maroon)
            Text("Events with a photo get noticed. Add one from last time, or a shot of the space.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photoNames, id: \.self) { name in
                    thumbnail(for: name)
                }
                if isImporting {
                    ProgressView()
                        .frame(width: 84, height: 84)
                        .background(Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func thumbnail(for name: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = PhotoStore.loadImage(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // The file is gone but the name is still on the event.
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                remove(name)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
            .accessibilityLabel("Remove photo")
        }
    }

    // MARK: - Actions

    /// Loads each picked item and writes it to disk. Runs off the main thread
    /// for the decode, then hops back to touch the binding.
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isImporting = true }

        var added: [String] = []
        for item in items {
            guard photoNames.count + added.count < limit else { break }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let name = PhotoStore.save(image) else { continue }
            added.append(name)
        }

        await MainActor.run {
            photoNames.append(contentsOf: added)
            selection = []
            isImporting = false
        }
    }

    private func remove(_ name: String) {
        PhotoStore.delete(named: name)
        photoNames.removeAll { $0 == name }
    }
}
