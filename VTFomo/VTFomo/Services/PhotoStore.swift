//
//  PhotoStore.swift
//  VT FOMO
//
//  Saves event photos to disk and loads them back.
//
//  Why not put the image in SwiftData? Because storing raw image data in the
//  database makes every fetch slow, even the ones that only need a title. So
//  the file goes in the documents directory and the database keeps the file
//  name. `Event.photoNames` holds either one of these file names or the name
//  of an image in Assets.xcassets, and `loadImage` tries both.
//
//  PARADIGM NOTE - PROCEDURAL: stateless functions. Same input, same result,
//  no object to construct or keep alive.
//

import UIKit

enum PhotoStore {

    /// Where event photos live.
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("EventPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Longest edge we keep. A 12 MP camera photo is about 4000px wide; storing
    /// that to show in a 240pt card wastes space and makes scrolling stutter.
    private static let maxDimension: CGFloat = 1600
    private static let jpegQuality: CGFloat = 0.8

    // MARK: - Saving

    /// Shrinks, compresses, and writes the image. Returns the file name to put
    /// in `Event.photoNames`, or nil if writing failed.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        let resized = downscale(image, to: maxDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }

        let name = "event-\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    // MARK: - Loading

    /// Loads a photo by name, checking the documents directory first and then
    /// the asset catalog, so seeded sample images keep working.
    static func loadImage(named name: String) -> UIImage? {
        let url = directory.appendingPathComponent(name)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return image
        }
        return UIImage(named: name)
    }

    // MARK: - Deleting

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    /// Removes files no event refers to any more. Worth calling occasionally so
    /// deleted events don't leave their photos behind forever.
    static func deleteOrphans(keeping names: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }

        // PARADIGM NOTE - FUNCTIONAL: filter then forEach, no index bookkeeping.
        files
            .filter { !names.contains($0.lastPathComponent) }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - Helpers

    /// Scales an image so its longest edge is `limit`, preserving aspect ratio.
    private static func downscale(_ image: UIImage, to limit: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > limit else { return image }

        let scale = limit / longest
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
