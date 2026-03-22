//
//  CKRClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import ComposableArchitecture
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import os

enum CKRError: Error, Equatable {
    case networkError
    case permissionDenied
    case notFound
    case unknown(String)

    static func fromFirestoreError(_ error: Error) -> CKRError {
        switch (error as NSError).code {
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.notFound.rawValue:
                return .notFound
            case FirestoreErrorCode.unavailable.rawValue:
                return .networkError
            default:
                return .unknown(error.localizedDescription)
        }
    }
}

struct MatchResult: Equatable {
    var success: Bool
    var groupCount: Int
    var groups: [MatchedGroup]
}

@DependencyClient
struct CKRClient {
    var newGame: @Sendable (_ newGame: CKRGame) async throws -> Void
    var updateGame: @Sendable (_ game: CKRGame) async throws -> Void
    var getGame: @Sendable () async -> Result<CKRGame?, CKRError> = { .success(nil) }
    var watchGame: @Sendable () -> AsyncStream<CKRGame?> = { AsyncStream { $0.finish() } }
    var deleteGame: @Sendable (_ gameId: String) async -> Result<Bool, CKRError> = { _ in .success(true) }
    var matchCohouses: @Sendable (_ gameId: String) async -> Result<MatchResult, CKRError> = { _ in .success(MatchResult(success: true, groupCount: 0, groups: [])) }
    var resetMatches: @Sendable (_ gameId: String) async -> Result<Bool, CKRError> = { _ in .success(true) }
    var updateEventSettings: @Sendable (_ gameId: String, _ settings: CKREventSettings) async -> Result<Bool, CKRError> = { _, _ in .success(true) }
    var confirmMatching: @Sendable (_ gameId: String) async -> Result<[GroupPlanning], CKRError> = { _ in .success([]) }
    var revealPlanning: @Sendable (_ gameId: String) async -> Result<Bool, CKRError> = { _ in .success(true) }

    // ── Edition management ──
    var createSpecialEdition: @Sendable (_ title: String, _ maxParticipants: Int, _ pricePerPersonCents: Int) async -> Result<(gameId: String, joinCode: String), CKRError> = { _, _, _ in .success(("", "")) }
    var saveDraftEdition: @Sendable (_ gameId: String, _ fields: [String: Any]) async -> Result<Bool, CKRError> = { _, _ in .success(true) }
    var publishEdition: @Sendable (_ gameId: String) async -> Result<String, CKRError> = { _ in .success("") }
    var getMyEditions: @Sendable () async -> Result<[CKRGame], CKRError> = { .success([]) }
}


extension CKRClient: DependencyKey {
    static let liveValue = Self(
        newGame: { newGame in
            let ckrGameRef = Firestore.firestore().collection("ckrGames").document(newGame.id.uuidString)
            try await ckrGameRef.setData(from: newGame)
        },
        updateGame: { game in
            let ckrGameRef = Firestore.firestore().collection("ckrGames").document(game.id.uuidString)
            try await ckrGameRef.setData(from: game, merge: true)
        },
        getGame: {
            do {
                let querySnapshot = try await Firestore.firestore().collection("ckrGames").getDocuments()
                let documents = querySnapshot.documents

                guard let document = documents.first else {
                    return .success(nil)
                }

                let game = try document.data(as: CKRGame.self)
                return .success(game)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        watchGame: {
            AsyncStream { continuation in
                let listener = Firestore.firestore()
                    .collection("ckrGames")
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            Logger.ckrLog.log(level: .error, "watchGame error: \(error.localizedDescription)")
                            continuation.yield(nil)
                            return
                        }
                        guard let snapshot else {
                            continuation.yield(nil)
                            return
                        }
                        let game = snapshot.documents.first.flatMap { try? $0.data(as: CKRGame.self) }
                        continuation.yield(game)
                    }
                continuation.onTermination = { _ in listener.remove() }
            }
        },
        deleteGame: { gameId in
            do {
                let functions = Functions.functions(region: "europe-west1")
                _ = try await functions.httpsCallable("deleteCKRGame").call([
                    "gameId": gameId
                ])
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        matchCohouses: { gameId in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let result = try await functions.httpsCallable("matchCohouses").call([
                    "gameId": gameId
                ])

                guard let data = result.data as? [String: Any] else {
                    return .failure(.unknown("Invalid response from matchCohouses"))
                }

                let success = data["success"] as? Bool ?? false
                let groupCount = data["groupCount"] as? Int ?? 0
                let rawGroups = (data["groups"] as? [[String]]) ?? []
                let groups = rawGroups.map { MatchedGroup(cohouseIds: $0) }

                return .success(MatchResult(
                    success: success,
                    groupCount: groupCount,
                    groups: groups
                ))
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        resetMatches: { gameId in
            do {
                let db = Firestore.firestore()
                try await db.collection("ckrGames").document(gameId).updateData([
                    "matchedGroups": FieldValue.delete(),
                    "matchedAt": FieldValue.delete(),
                ])
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        updateEventSettings: { gameId, settings in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let formatter = ISO8601DateFormatter()
                let data: [String: Any] = [
                    "gameId": gameId,
                    "aperoStartTime": formatter.string(from: settings.aperoStartTime),
                    "aperoEndTime": formatter.string(from: settings.aperoEndTime),
                    "dinerStartTime": formatter.string(from: settings.dinerStartTime),
                    "dinerEndTime": formatter.string(from: settings.dinerEndTime),
                    "partyStartTime": formatter.string(from: settings.partyStartTime),
                    "partyEndTime": formatter.string(from: settings.partyEndTime),
                    "partyAddress": settings.partyAddress,
                    "partyName": settings.partyName,
                    "partyNote": settings.partyNote ?? ""
                ]
                _ = try await functions.httpsCallable("updateEventSettings").call(data)
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        confirmMatching: { gameId in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let result = try await functions.httpsCallable("confirmMatching").call([
                    "gameId": gameId
                ])

                guard let data = result.data as? [String: Any],
                      let rawPlannings = data["groupPlannings"] as? [[String: Any]]
                else {
                    return .failure(.unknown("Invalid response from confirmMatching"))
                }

                let plannings = rawPlannings.compactMap { raw -> GroupPlanning? in
                    guard let groupIndex = raw["groupIndex"] as? Int,
                          let cohouseA = raw["cohouseA"] as? String,
                          let cohouseB = raw["cohouseB"] as? String,
                          let cohouseC = raw["cohouseC"] as? String,
                          let cohouseD = raw["cohouseD"] as? String
                    else { return nil }
                    return GroupPlanning(
                        groupIndex: groupIndex,
                        cohouseA: cohouseA,
                        cohouseB: cohouseB,
                        cohouseC: cohouseC,
                        cohouseD: cohouseD
                    )
                }

                return .success(plannings)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        revealPlanning: { gameId in
            do {
                let functions = Functions.functions(region: "europe-west1")
                _ = try await functions.httpsCallable("revealPlanning").call([
                    "gameId": gameId
                ])
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        createSpecialEdition: { title, maxParticipants, pricePerPersonCents in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let result = try await functions.httpsCallable("createSpecialEdition").call([
                    "title": title,
                    "maxParticipants": maxParticipants,
                    "pricePerPersonCents": pricePerPersonCents,
                ] as [String: Any])

                guard let data = result.data as? [String: Any],
                      let gameId = data["gameId"] as? String,
                      let joinCode = data["joinCode"] as? String
                else {
                    return .failure(.unknown("Invalid response from createSpecialEdition"))
                }
                return .success((gameId: gameId, joinCode: joinCode))
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        saveDraftEdition: { gameId, fields in
            do {
                let functions = Functions.functions(region: "europe-west1")
                _ = try await functions.httpsCallable("saveDraftEdition").call([
                    "gameId": gameId,
                    "fields": fields,
                ] as [String: Any])
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        publishEdition: { gameId in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let result = try await functions.httpsCallable("publishEdition").call([
                    "gameId": gameId
                ])
                let data = result.data as? [String: Any]
                let joinCode = data?["joinCode"] as? String ?? ""
                return .success(joinCode)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        getMyEditions: {
            do {
                guard let callerUid = Auth.auth().currentUser?.uid else {
                    return .failure(.notFound)
                }

                // Super admins see all special editions; edition admins see only their own
                let callerToken = try await Auth.auth().currentUser?.getIDTokenResult()
                let role = callerToken?.claims["role"] as? String

                var query = Firestore.firestore()
                    .collection("ckrGames")
                    .whereField("editionType", isEqualTo: "special")

                if role != "super_admin" {
                    query = query.whereField("createdByAuthUid", isEqualTo: callerUid)
                }

                let snapshot = try await query.getDocuments()
                let editions = snapshot.documents.compactMap { doc -> CKRGame? in
                    try? doc.data(as: CKRGame.self)
                }
                return .success(editions)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        }
    )

    static var previewValue: CKRClient {
        Self(
            newGame: { _ in },
            updateGame: { _ in },
            getGame: { .success(nil) },
            watchGame: { AsyncStream { $0.finish() } },
            deleteGame: { _ in .success(true) },
            matchCohouses: { _ in .success(MatchResult(success: true, groupCount: 0, groups: [])) },
            resetMatches: { _ in .success(true) },
            updateEventSettings: { _, _ in .success(true) },
            confirmMatching: { _ in .success([]) },
            revealPlanning: { _ in .success(true) },
            createSpecialEdition: { _, _, _ in .success(("preview-id", "ABC123")) },
            saveDraftEdition: { _, _ in .success(true) },
            publishEdition: { _ in .success("ABC123") },
            getMyEditions: { .success([]) }
        )
    }

    static var testValue: CKRClient {
        Self(
            newGame: { _ in },
            updateGame: { _ in },
            getGame: { .success(nil) },
            watchGame: { AsyncStream { $0.finish() } },
            deleteGame: { _ in .success(true) },
            matchCohouses: { _ in .success(MatchResult(success: true, groupCount: 0, groups: [])) },
            resetMatches: { _ in .success(true) },
            updateEventSettings: { _, _ in .success(true) },
            confirmMatching: { _ in .success([]) },
            revealPlanning: { _ in .success(true) },
            createSpecialEdition: { _, _, _ in .success(("test-id", "TEST12")) },
            saveDraftEdition: { _, _ in .success(true) },
            publishEdition: { _ in .success("TEST12") },
            getMyEditions: { .success([]) }
        )
    }
}

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
