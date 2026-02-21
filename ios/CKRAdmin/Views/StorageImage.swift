//
//  StorageImage.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 21/05/2025.
//

import ComposableArchitecture
import Dependencies
import FirebaseStorage
import SwiftUI

struct StorageImage: View {
    let path: String
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Dependency(\.storageClient) var storageClient

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else {
                Color.clear
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        isLoading = true
        errorMessage = nil
        let result = await storageClient.loadImage(path)
        switch result {
            case .success(let uiImage): image = uiImage
            case .failure(let error): errorMessage = errorMessage(for: error)
        }
        isLoading = false
    }

    private func errorMessage(for error: StorageClientError) -> String {
        switch error {
            case .networkError: return "Network error."
            case .permissionDenied: return "Permission denied."
            case .invalidData: return "Invalid image data."
            case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }
}
