//
//  CKRClient.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions
import os

// MARK: - Error

enum CKRError: Error {
    case firebaseError(String)
    case noDocumentAvailable
}

// MARK: - Client Interface

@DependencyClient
struct CKRClient {
    var getLast: @Sendable () async throws -> Result<CKRGame?, CKRError>
    var listenToGame: @Sendable () -> AsyncStream<CKRGame?> = { .never }
    var confirmRegistration: @Sendable (
        _ gameId: String,
        _ cohouseId: String,
        _ paymentIntentId: String
    ) async throws -> Void
    var cancelReservation: @Sendable (
        _ gameId: String,
        _ cohouseId: String
    ) async throws -> Void
    var getMyPlanning: @Sendable (
        _ gameId: String,
        _ cohouseId: String
    ) async throws -> CKRMyPlanning
}

// MARK: - Implementations

extension CKRClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        getLast: {
            // Demo mode: return current game state without hitting Firestore.
            // If a game already exists in shared state (e.g. after registration updated it),
            // preserve it instead of resetting to the default demo game.
            if DemoMode.isActive {
                @Shared(.ckrGame) var ckrGame
                if let existingGame = ckrGame {
                    return .success(existingGame)
                }
                $ckrGame.withLock { $0 = DemoMode.demoCKRGame }
                return .success(DemoMode.demoCKRGame)
            }

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

                let game: CKRGame?
                do {
                    game = try document.data(as: CKRGame.self)
                } catch {
                    Logger.ckrLog.error("Failed to decode CKRGame document \(document.documentID): \(error)")
                    game = nil
                }
                $ckrGame.withLock { $0 = game }
                return .success(game)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        },
        listenToGame: {
            AsyncStream { continuation in
                if DemoMode.isActive {
                    @Shared(.ckrGame) var ckrGame
                    $ckrGame.withLock { $0 = DemoMode.demoCKRGame }
                    continuation.yield(DemoMode.demoCKRGame)
                    return
                }

                let listener = Firestore.firestore()
                    .collection("ckrGames")
                    .order(by: "publishedTimestamp", descending: true)
                    .limit(to: 1)
                    .addSnapshotListener { snapshot, error in
                        guard let snapshot, error == nil else {
                            if let error {
                                Logger.ckrLog.error("Game listener error: \(error)")
                            }
                            return
                        }

                        let game: CKRGame?
                        if let document = snapshot.documents.first {
                            do {
                                game = try document.data(as: CKRGame.self)
                            } catch {
                                Logger.ckrLog.error("Failed to decode CKRGame in listener: \(error)")
                                game = nil
                            }
                        } else {
                            game = nil
                        }

                        @Shared(.ckrGame) var ckrGame
                        $ckrGame.withLock { $0 = game }
                        continuation.yield(game)
                    }

                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },
        confirmRegistration: { gameId, cohouseId, paymentIntentId in
            // Demo mode: skip Cloud Function call (local state update is
            // handled by the reducer which has access to participant count)
            if DemoMode.isActive {
                Logger.ckrLog.info("[Demo] Simulating registration confirmation for game")
                return
            }

            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("confirmRegistration")

            let data: [String: Any] = [
                "gameId": gameId,
                "cohouseId": cohouseId,
                "paymentIntentId": paymentIntentId
            ]

            _ = try await callable.call(data)
        },
        cancelReservation: { gameId, cohouseId in
            if DemoMode.isActive {
                Logger.ckrLog.info("[Demo] Simulating reservation cancellation")
                return
            }

            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("cancelReservation")

            _ = try await callable.call([
                "gameId": gameId,
                "cohouseId": cohouseId
            ] as [String: Any])
        },
        getMyPlanning: { gameId, cohouseId in
            // Demo mode: return mock planning without calling Cloud Function
            if DemoMode.isActive {
                return DemoMode.demoPlanning
            }

            let functions = Functions.functions(region: "europe-west1")
            let result = try await functions.httpsCallable("getMyPlanning").call([
                "gameId": gameId,
                "cohouseId": cohouseId
            ])

            guard let data = result.data as? [String: Any],
                  let planningData = data["planning"] as? [String: Any],
                  let aperoData = planningData["apero"] as? [String: Any],
                  let dinerData = planningData["diner"] as? [String: Any],
                  let partyData = planningData["party"] as? [String: Any]
            else {
                throw CKRError.firebaseError("Invalid response from getMyPlanning")
            }

            let formatter = ISO8601DateFormatter()

            func parseStep(_ raw: [String: Any]) -> PlanningStep {
                PlanningStep(
                    role: (raw["role"] as? String) == "host" ? .host : .visitor,
                    cohouseName: raw["cohouseName"] as? String ?? "Unknown",
                    address: raw["address"] as? String ?? "",
                    hostPhone: raw["hostPhone"] as? String,
                    visitorPhone: raw["visitorPhone"] as? String,
                    totalPeople: raw["totalPeople"] as? Int ?? 0,
                    dietarySummary: (raw["dietarySummary"] as? [String: Int]) ?? [:],
                    startTime: formatter.date(from: raw["startTime"] as? String ?? "") ?? Date(),
                    endTime: formatter.date(from: raw["endTime"] as? String ?? "") ?? Date()
                )
            }

            let party = PartyInfo(
                name: partyData["name"] as? String ?? "",
                address: partyData["address"] as? String ?? "",
                startTime: formatter.date(from: partyData["startTime"] as? String ?? "") ?? Date(),
                endTime: formatter.date(from: partyData["endTime"] as? String ?? "") ?? Date(),
                note: partyData["note"] as? String
            )

            return CKRMyPlanning(
                apero: parseStep(aperoData),
                diner: parseStep(dinerData),
                party: party
            )
        }
    )

}

// MARK: - Registration

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
