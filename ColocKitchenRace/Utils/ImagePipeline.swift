//
//  ImagePipeline.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 07/10/2025.
//

import UIKit

enum ImagePipeline {

    // MARK: - Global defaults (tweak these to change all uploads at once)

    /// Maximum dimension (width or height) after resize.
    static let defaultMaxDimension: CGFloat = 1200

    /// Maximum file size in bytes.
    static let defaultMaxBytes: Int = 500_000 // 500 KB

    /// Starting JPEG quality for iterative compression.
    static let defaultStartQuality: CGFloat = 0.8

    /// Minimum JPEG quality before giving up.
    static let defaultMinQuality: CGFloat = 0.1

    /// Quality decrement per iteration.
    static let qualityStep: CGFloat = 0.1

    // MARK: - Public API

    /// Resize + iteratively compress a `UIImage` to JPEG data that fits within `maxBytes`.
    ///
    /// Usage — zero config for most call sites:
    /// ```swift
    /// guard let data = ImagePipeline.compress(image: photo) else { … }
    /// ```
    ///
    /// Override for a specific use-case:
    /// ```swift
    /// ImagePipeline.compress(image: photo, maxDimension: 800, maxBytes: 200_000)
    /// ```
    static func compress(
        image: UIImage,
        maxDimension: CGFloat = defaultMaxDimension,
        maxBytes: Int = defaultMaxBytes,
        startQuality: CGFloat = defaultStartQuality,
        minQuality: CGFloat = defaultMinQuality
    ) -> Data? {
        // 1. Resize
        guard let resized = resize(image, maxDimension: maxDimension) else { return nil }

        // 2. Iterative JPEG compression until we fit within maxBytes
        var quality = startQuality
        guard var data = resized.jpegData(compressionQuality: quality) else { return nil }

        while data.count > maxBytes && quality > minQuality {
            quality -= qualityStep
            if let newData = resized.jpegData(compressionQuality: max(quality, minQuality)) {
                data = newData
            } else {
                break
            }
        }

        return data
    }

    // MARK: - Helpers

    /// Format human-readable file size (e.g. "412.3 KB")
    static func humanSize(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b < 1024 { return "\(Int(b)) B" }
        if b < 1_048_576 { return String(format: "%.1f KB", b / 1024) }
        return String(format: "%.1f MB", b / 1_048_576)
    }

    // MARK: - Private

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image } // already small enough

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
