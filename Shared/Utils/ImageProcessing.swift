//
//  ImageProcessing.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 31/05/2025.
//

import UIKit

struct ImageProcessing {
    static func prepareImageForUpload(
        image: UIImage,
        maxDimension: CGFloat = 1024,
        maxFileSize: Int = 1_000_000,
        minCompression: CGFloat = 0.1
    ) -> Data? {
        // Resize if needed
        let resizedImage: UIImage = {
            let width = image.size.width
            let height = image.size.height
            let largestSide = max(width, height)
            guard largestSide > maxDimension else { return image }

            let scale = maxDimension / largestSide
            let newSize = CGSize(width: width * scale, height: height * scale)

            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }()

        // Compress
        var compression: CGFloat = 1.0
        guard var data = resizedImage.jpegData(compressionQuality: compression) else { return nil }

        while data.count > maxFileSize && compression > minCompression {
            compression -= 0.1
            if let newData = resizedImage.jpegData(compressionQuality: compression) {
                data = newData
            } else {
                break
            }
        }

        return data
    }
}
