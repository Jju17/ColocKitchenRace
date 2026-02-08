//
//  CKRClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import FirebaseFirestore

// MARK: - Error

enum CKRError: Error {
    case firebaseError(String)
    case noDocumentAvailable
}

// MARK: - Client Interface

@DependencyClient
struct CKRClient {
    var getLast: @Sendable () async throws -> Result<CKRGame?, CKRError>
    var registerCohouse: (_ cohouse: Cohouse) -> Result<Bool, CKRError> = { _ in .success(true) }
}

// MARK: - Implementations

extension CKRClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        getLast: {
            do {
                @Shared(.ckrGame) var ckrGame

                let snapshot = try await Firestore.firestore()
                    .collection("ckrGames")
                    .order(by: "publishedTimestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments()

                guard let document = snapshot.documents.first else {
                    $ckrGame.withLock { $0 = nil }
                    return .failure(.noDocumentAvailable)
                }

                let game = try? document.data(as: CKRGame.self)
                $ckrGame.withLock { $0 = game }
                return .success(game)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        },
        registerCohouse: { cohouse in
            // TODO: Implement cohouse registration for CKR game
            return .success(true)
        }
    )

    // MARK: Test

    static let testValue = Self(
        getLast: { .success(nil) },
        registerCohouse: { _ in .success(true) }
    )

    // MARK: Preview

    static let previewValue: CKRClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
