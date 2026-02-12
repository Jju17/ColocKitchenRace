//
//  ChallengesClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import FirebaseFirestore

// MARK: - Error

enum ChallengesClientError: Error {
    case failed
    case failedWithError(String)
}

// MARK: - Client Interface

@DependencyClient
struct ChallengesClient {
    var getAll: @Sendable () async throws -> [Challenge]
}

// MARK: - Implementations

extension ChallengesClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        getAll: {
            @Shared(.challenges) var challenges

            let snapshot = try await Firestore.firestore()
                .collection("challenges")
                .getDocuments()

            let allChallenges = snapshot.documents.compactMap { document in
                try? document.data(as: Challenge.self)
            }
            .sorted { $0.endDate < $1.endDate }

            $challenges.withLock { $0 = allChallenges }
            return allChallenges
        }
    )

    // MARK: Test

    static let testValue = Self(
        getAll: { [] }
    )

    // MARK: Preview

    static let previewValue: ChallengesClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var challengesClient: ChallengesClient {
        get { self[ChallengesClient.self] }
        set { self[ChallengesClient.self] = newValue }
    }
}
