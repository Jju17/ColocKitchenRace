//
//  ChallengesClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

enum ChallengesClientError: Error {
    case failed
    case failedWithError(String)
}

@DependencyClient
struct ChallengesClient {
    var getAll: @Sendable () async throws -> Result<[Challenge], ChallengesClientError>
}

extension ChallengesClient: DependencyKey {
    static let liveValue = Self(
        getAll: {
            do {
                @Shared(.challenges) var challenges

                let querySnapshot = try await Firestore.firestore().collection("challenges")
//                    .order(by: "publicationTimestamp", descending: true) //TODO: Sort & order challenges here.
                    .getDocuments()

                let documents = querySnapshot.documents
                let allChallenges = documents.compactMap { document in
                    try? document.data(as: Challenge.self)
                }

                $challenges.withLock { $0 = allChallenges }
                return .success(allChallenges)
            } catch {
                return .failure(ChallengesClientError.failedWithError(error.localizedDescription))
            }
        }
    )

    static var previewValue: ChallengesClient {
        return .testValue
    }
}

extension DependencyValues {
    var challengesClient: ChallengesClient {
        get { self[ChallengesClient.self] }
        set { self[ChallengesClient.self] = newValue }
    }
}
