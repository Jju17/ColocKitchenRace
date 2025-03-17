//
//  GlobalInfoClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

@DependencyClient
struct GlobalInfoClient {
    var getLast: @Sendable () async throws -> Result<GlobalInfo?, GlobalInfoError>
}

enum GlobalInfoError: Error {
    case firebaseError(String)
    case noDocumentAvailable
}

extension GlobalInfoClient: DependencyKey {
    static let liveValue = Self(
        getLast: {
            do {
                @Shared(.globalInfos) var globalInfos
                
                let querySnapshot = try await Firestore.firestore().collection("general")
                    .order(by: "publishedTimestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments()

                guard let document = querySnapshot.documents.first
                else {
                    $globalInfos.withLock { $0 = nil }
                    return .failure(.noDocumentAvailable)
                }

                let infos = try? document.data(as: GlobalInfo.self)

                $globalInfos.withLock { $0 = infos }
                return .success(globalInfos)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        }
    )
}

extension DependencyValues {
    var globalInfoClient: GlobalInfoClient {
        get { self[GlobalInfoClient.self] }
        set { self[GlobalInfoClient.self] = newValue }
    }
}
