//
//  EditionClient.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 21/03/2026.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions
import os

// MARK: - Error

enum EditionClientError: Error, LocalizedError {
    case notFound
    case alreadyInEdition
    case registeredCannotLeave
    case firebaseError(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No edition found with this code"
        case .alreadyInEdition:
            return "You are already in a special edition. Leave it first."
        case .registeredCannotLeave:
            return "Cannot leave an edition you are registered for."
        case .firebaseError(let msg):
            return msg
        }
    }
}

// MARK: - Response types

struct JoinEditionResponse: Equatable {
    let gameId: String
    let title: String
    let editionType: String
}

// MARK: - Client Interface

@DependencyClient
struct EditionClient {
    /// Join a special edition by its 6-character code.
    var joinByCode: @Sendable (_ code: String) async throws -> JoinEditionResponse

    /// Leave the current special edition.
    var leave: @Sendable (_ gameId: String) async throws -> Void

    /// Fetch a specific edition by its game ID.
    var getEdition: @Sendable (_ gameId: String) async throws -> CKRGame?
}

// MARK: - Implementations

extension EditionClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        joinByCode: { code in
            if DemoMode.isActive {
                Logger.ckrLog.info("[Demo] Simulating join edition by code")
                return JoinEditionResponse(
                    gameId: "demo-special-edition",
                    title: "Demo Edition",
                    editionType: "special"
                )
            }

            let functions = Functions.functions(region: "europe-west1")
            let result = try await functions.httpsCallable("joinEditionByCode").call([
                "joinCode": code
            ])

            guard let data = result.data as? [String: Any],
                  let gameId = data["gameId"] as? String,
                  let title = data["title"] as? String
            else {
                throw EditionClientError.firebaseError("Invalid response from joinEditionByCode")
            }

            let editionType = data["editionType"] as? String ?? "special"

            // Update local user state
            @Shared(.userInfo) var userInfo
            $userInfo.withLock { $0?.activeEditionId = gameId }

            return JoinEditionResponse(
                gameId: gameId,
                title: title,
                editionType: editionType
            )
        },
        leave: { gameId in
            if DemoMode.isActive {
                Logger.ckrLog.info("[Demo] Simulating leave edition")
                @Shared(.userInfo) var userInfo
                $userInfo.withLock { $0?.activeEditionId = nil }
                return
            }

            let functions = Functions.functions(region: "europe-west1")
            _ = try await functions.httpsCallable("leaveEdition").call([
                "gameId": gameId
            ])

            // Update local user state
            @Shared(.userInfo) var userInfo
            $userInfo.withLock { $0?.activeEditionId = nil }
        },
        getEdition: { gameId in
            if DemoMode.isActive {
                return nil
            }

            let doc = try await Firestore.firestore()
                .collection("ckrGames")
                .document(gameId)
                .getDocument()

            guard doc.exists else { return nil }

            return try doc.data(as: CKRGame.self)
        }
    )

    static let previewValue = Self(
        joinByCode: { _ in JoinEditionResponse(gameId: "preview-id", title: "Preview Edition", editionType: "special") },
        leave: { _ in },
        getEdition: { _ in nil }
    )

    static let testValue = Self(
        joinByCode: { _ in JoinEditionResponse(gameId: "test-id", title: "Test Edition", editionType: "special") },
        leave: { _ in },
        getEdition: { _ in nil }
    )
}

// MARK: - Registration

extension DependencyValues {
    var editionClient: EditionClient {
        get { self[EditionClient.self] }
        set { self[EditionClient.self] = newValue }
    }
}
