//
//  CohouseClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/06/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

@DependencyClient
struct CohouseClient {
    var add: @Sendable (_ newCohouse: Cohouse) throws -> Result<Bool, Error>
    var get: @Sendable (_ id: String) async throws -> Result<Cohouse, Error>
    var set: @Sendable (_ id: String, _ newCohouse: Cohouse) async throws -> Result<Bool, Error>
}


extension CohouseClient: DependencyKey {
    static let liveValue = Self(
        add: { newCohouse in
            do {
                try Firestore.firestore().collection("cohouses").document().setData(from: newCohouse)
                @Shared(.cohouse) var currentCohouse
                currentCohouse = newCohouse
                return .success(true)
            } catch {
                return .failure(error)
            }
        },
        get: { id in
            do {
                let cohouse = try await Firestore.firestore().collection("cohouses").document(id).getDocument(as: Cohouse.self)
                @Shared(.cohouse) var currentCohouse
                currentCohouse = cohouse
                return .success(cohouse)
            } catch {
                return .failure(error)
            }
        },
        set: { id, newCohouse in
            do {
                try Firestore.firestore().collection("cohouses").document(id).setData(from: newCohouse)
                @Shared(.cohouse) var currentCohouse
                currentCohouse = newCohouse
                return .success(true)
            } catch {
                return .failure(error)
            }
        }
    )

    static var previewValue: CohouseClient {
        return .testValue
    }
}

extension DependencyValues {
    var cohouseClient: CohouseClient {
        get { self[CohouseClient.self] }
        set { self[CohouseClient.self] = newValue }
    }
}
