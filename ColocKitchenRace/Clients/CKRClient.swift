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
        _ cohouseType: String,
        _ paymentIntentId: String?
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
            // Demo mode: return mock game without hitting Firestore
            if DemoMode.isActive {
                @Shared(.ckrGame) var ckrGame
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

                let game = try? document.data(as: CKRGame.self)
                $ckrGame.withLock { $0 = game }
                return .success(game)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        },
        registerForGame: { gameId, cohouseId, attendingUserIds, averageAge, cohouseType, paymentIntentId in
            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("registerForGame")

            var data: [String: Any] = [
                "gameId": gameId,
                "cohouseId": cohouseId,
                "attendingUserIds": attendingUserIds,
                "averageAge": averageAge,
                "cohouseType": cohouseType
            ]

            if let paymentIntentId {
                data["paymentIntentId"] = paymentIntentId
            }

            _ = try await callable.call(data)

            // Refresh local ckrGame to reflect updated registration
            @Shared(.ckrGame) var ckrGame
            if var game = ckrGame {
                game.cohouseIDs.append(cohouseId)
                game.totalRegisteredParticipants += attendingUserIds.count
                $ckrGame.withLock { $0 = game }
            }
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
