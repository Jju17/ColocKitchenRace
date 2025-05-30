//
//  FullScreenImageView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 30/05/2025.
//

import ComposableArchitecture
import SwiftUI

struct FullScreenImageView: View {
    let imagePath: String
    @Environment(\.dismiss) var dismiss

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @Dependency(\.storageClient) var storageClient

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = loadedImage {
                ZoomableImageView(image: image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView()
            } else {
                Text("Image failed to load").foregroundColor(.white)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .position(x: UIScreen.main.bounds.width - 40, y: 40)
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        let result = await storageClient.loadImage(imagePath)
        if case .success(let img) = result {
            loadedImage = img
        }
        isLoading = false
    }
}
