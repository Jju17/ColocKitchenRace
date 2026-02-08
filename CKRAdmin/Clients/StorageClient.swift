//
//  StorageClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 21/05/2025.
//

import UIKit
import Dependencies
import DependenciesMacros
import FirebaseStorage
import os

// MARK: - Error

public enum StorageClientError: Error, Equatable {
    case networkError
    case permissionDenied
    case invalidData
    case unknown(String)
}

// MARK: - Client Interface

@DependencyClient
public struct StorageClient {
    public var loadImage: @Sendable (_ path: String) async -> Result<UIImage?, StorageClientError> = { _ in .failure(.networkError) }
    public var uploadImage: @Sendable (_ data: Data, _ path: String) async throws -> String = { _, _ in "" }
}

// MARK: - Implementations

extension StorageClient: DependencyKey {

    // MARK: Live

    public static let liveValue = Self(
        loadImage: { path in
            do {
                let ref = Storage.storage().reference(withPath: path)
                let data = try await ref.data(maxSize: 4 * 1024 * 1024)

                guard let image = UIImage(data: data) else {
                    return .failure(.invalidData)
                }

                Logger.storageLog.log(level: .info, "Loaded image at \(path)")
                return .success(image)
            } catch let error as NSError {
                Logger.storageLog.log(level: .fault, "Load image failed at \(path): \(error.localizedDescription)")
                switch error.code {
                case StorageErrorCode.unauthorized.rawValue:
                    return .failure(.permissionDenied)
                case StorageErrorCode.unknown.rawValue where error.domain == NSURLErrorDomain:
                    return .failure(.networkError)
                default:
                    return .failure(.unknown(error.localizedDescription))
                }
            }
        },
        uploadImage: { data, path in
            let ref = Storage.storage().reference(withPath: path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            Logger.storageLog.log(level: .info, "Uploaded image to \(path)")
            return url.absoluteString
        }
    )

    // MARK: Test

    public static let testValue = Self(
        loadImage: { _ in .success(nil) },
        uploadImage: { _, _ in "https://test.local/image.jpg" }
    )

    // MARK: Preview

    public static let previewValue = Self(
        loadImage: { _ in .success(UIImage(systemName: "photo")) },
        uploadImage: { _, _ in "https://example.com/mock.jpg" }
    )
}

// MARK: - Registration

public extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
