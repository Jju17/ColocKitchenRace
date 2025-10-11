//
//  ImagePipeline.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 07/10/2025.
//

import UIKit

enum ImagePipeline {
  /// Resize (maxDimension) and compress (quality) in JPEG format.
  static func jpegDataCompressed(from image: UIImage,
                                 maxDimension: CGFloat = 2000,
                                 quality: CGFloat = 0.7) -> Data? {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }

    let maxSide = max(size.width, size.height)
    let scale = max(1, maxSide / maxDimension)
    let newSize = CGSize(width: size.width/scale, height: size.height/scale)

    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let downscaled = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return downscaled.jpegData(compressionQuality: quality)
  }

  /// Format human-readable (ex. "1.8 MB")
  static func humanSize(_ bytes: Int) -> String {
    let b = Double(bytes)
    if b < 1024 { return "\(Int(b)) B" }
    if b < 1_048_576 { return String(format: "%.1f KB", b/1024) }
    return String(format: "%.1f MB", b/1_048_576)
  }
}
