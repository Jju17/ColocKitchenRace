//
//  CKRClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

@DependencyClient
struct CKRClient {
    var getLast: @Sendable () async throws -> Result<CKRGame?, CKRError>
    var registerCohouse: (_ cohouse: Cohouse) -> Result<Bool, CKRError> = { _ in .success(true) }
}

enum CKRError: Error {
    case firebaseError(String)
    case noDocumentAvailable
}

extension CKRClient: DependencyKey {
    static let liveValue = Self(
        getLast: {
            do {
                @Shared(.ckrGame) var ckrGame

                let querySnapshot = try await Firestore.firestore().collection("ckrGames")
                    .order(by: "publishedTimestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments()

                guard let document = querySnapshot.documents.first
                else {
                    $ckrGame.withLock { $0 = nil }
                    return .failure(.noDocumentAvailable)
                }

                let infos = try? document.data(as: CKRGame.self)

                $ckrGame.withLock { $0 = infos }
                return .success(ckrGame)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        },
        registerCohouse: { cohouse in
               return .success(true)
        }
    )
}

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
