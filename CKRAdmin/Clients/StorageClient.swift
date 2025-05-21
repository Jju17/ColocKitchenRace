//
//  StorageClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 21/05/2025.
//

import SwiftUI
import Dependencies
import DependenciesMacros
import FirebaseStorage
import os

enum StorageError: Error, Equatable {
    case networkError
    case permissionDenied
    case invalidData
    case unknown(String)
}

@DependencyClient
struct StorageClient {
    var loadImage: @Sendable (String) async -> Result<UIImage?, StorageError> = { _ in .success(nil) }
}

extension StorageClient: DependencyKey {
    static let liveValue = Self(
        loadImage: { path in
            do {
                let storageRef = Storage.storage().reference(withPath: path)
                let data = try await storageRef.data(maxSize: 2 * 1024 * 1024) // 2MB max
                if let uiImage = UIImage(data: data) {
                    Logger.storageLog.log(level: .info, "Successfully loaded image from path: \(path)")
                    return .success(uiImage)
                } else {
                    return .failure(.invalidData)
                }
            } catch let error as NSError {
                Logger.storageLog.log(level: .fault, "Failed to load image from path: \(path), error: \(error.localizedDescription)")
                switch error.code {
                case StorageErrorCode.unauthorized.rawValue:
                    return .failure(.permissionDenied)
                case StorageErrorCode.unknown.rawValue where error.domain == "NSURLErrorDomain":
                    return .failure(.networkError)
                default:
                    return .failure(.unknown(error.localizedDescription))
                }
            }
        }
    )

    static var previewValue = Self(
        loadImage: { _ in .success(UIImage(systemName: "photo")) }
    )

    static var testValue = Self(
        loadImage: { _ in .success(nil) }
    )
}

extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
