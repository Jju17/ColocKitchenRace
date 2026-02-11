//
//  CKRClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Error

enum CKRError: Error {
    case firebaseError(String)
    case noDocumentAvailable
}

// MARK: - Client Interface

@DependencyClient
struct CKRClient {
    var getLast: @Sendable () async throws -> Result<CKRGame?, CKRError>
    var registerForGame: @Sendable (
        _ gameId: String,
        _ cohouseId: String,
        _ attendingUserIds: [String],
        _ averageAge: Int,
        _ cohouseType: String
    ) async throws -> Void
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
        registerForGame: { gameId, cohouseId, attendingUserIds, averageAge, cohouseType in
            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("registerForGame")

            let data: [String: Any] = [
                "gameId": gameId,
                "cohouseId": cohouseId,
                "attendingUserIds": attendingUserIds,
                "averageAge": averageAge,
                "cohouseType": cohouseType
            ]

            _ = try await callable.call(data)

            // Refresh local ckrGame to reflect updated participantsID
            @Shared(.ckrGame) var ckrGame
            if var game = ckrGame {
                game.participantsID.append(cohouseId)
                $ckrGame.withLock { $0 = game }
            }
        }
    )

    // MARK: Test

    static let testValue = Self()

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
