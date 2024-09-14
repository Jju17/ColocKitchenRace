//
//  CohouseClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/06/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

enum CohouseClientError: Error {
    case failed
    case failedWithError(String)
}

@DependencyClient
struct CohouseClient {
    var add: @Sendable (_ newCohouse: Cohouse) async throws -> Result<Bool, Error>
    var get: @Sendable (_ id: String) async throws -> Result<Cohouse, Error>
    var getByCode: @Sendable (_ code: String) async throws -> Result<Cohouse, CohouseClientError>
    var set: @Sendable (_ id: String, _ newCohouse: Cohouse) async throws -> Result<Bool, Error>
    var setUser: @Sendable (_ user: CohouseUser, _ cohouseId: String) async throws -> Void
    var quitCohouse: @Sendable () async -> Void
}

extension CohouseClient: DependencyKey {
    static let liveValue = Self(
        add: { newCohouse in
            do {
                @Shared(.cohouse) var currentCohouse

                let cohouseRef = Firestore.firestore().collection("cohouses").document(newCohouse.id.uuidString)
                try cohouseRef.setData(from: newCohouse.toFIRCohouse)

                // Reference to the "users" collection within the new "cohouse" document
                let usersCollectionRef = cohouseRef.collection("users")
                for user in newCohouse.users {
                    try usersCollectionRef.document(user.id.uuidString).setData(from: user)
                }

                await $currentCohouse.withLock { $0 = newCohouse }
                return .success(true)
            } catch {
                return .failure(error)
            }
        },
        get: { id in
            do {
                @Shared(.cohouse) var currentCohouse

                let cohouseRef = Firestore.firestore().collection("cohouses").document(id)
                let firCohouse = try await cohouseRef.getDocument(as: FirestoreCohouse.self)

                let userCollectionRef = cohouseRef.collection("users")
                let querySnapshot = try await userCollectionRef.getDocuments()

                let cohouseUsers = try querySnapshot.documents.map {
                    try $0.data(as: CohouseUser.self)
                }

                let cohouse = firCohouse.toCohouseObject(with: cohouseUsers)
                await $currentCohouse.withLock { $0 = cohouse }
                return .success(cohouse)
            } catch {
                return .failure(error)
            }
        },
        getByCode: { code in
            do {
                guard let cohouseSnapshot = try await Firestore
                    .firestore()
                    .collection("cohouses")
                    .whereField("code", isEqualTo: code)
                    .getDocuments()
                    .documents
                    .first
                else { return .failure(.failed) }

                let cohouseRef = cohouseSnapshot.reference
                let firCohouse = try await cohouseRef.getDocument(as: FirestoreCohouse.self)

                let userCollectionRef = cohouseRef.collection("users")
                let cohouseUsersSnapshot = try await userCollectionRef.getDocuments()

                let cohouseUsers = try cohouseUsersSnapshot.documents.map {
                    try $0.data(as: CohouseUser.self)
                }

                let cohouse = firCohouse.toCohouseObject(with: cohouseUsers)
                return .success(cohouse)
            } catch {
                return .failure(.failedWithError(error.localizedDescription))
            }
        },
        set: { id, newCohouse in
            do {
                @Shared(.cohouse) var currentCohouse

                let cohouseRef = Firestore.firestore().collection("cohouses").document(id)
                try cohouseRef.setData(from: newCohouse.toFIRCohouse)

                // Reference to the "users" collection within the new "cohouse" document
                let usersCollectionRef = cohouseRef.collection("users")
                for user in newCohouse.users {
                    try usersCollectionRef.addDocument(from: user)
                }

                await $currentCohouse.withLock { $0 = newCohouse }
                return .success(true)
            } catch {
                return .failure(error)
            }
        },
        setUser: { user, cohouseId in
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

            let cohouseRef = Firestore.firestore().collection("cohouses").document(cohouseId)
            let usersCollectionRef = cohouseRef.collection("users")

            guard let userInfo else { return }

            // Set personnal ID to selected user in cohouse
            try await usersCollectionRef.document(user.id.uuidString).updateData(["userId": userInfo.id.uuidString])
            await $cohouse.withLock { cohouse in
                guard let userId = cohouse?.users.index(id: user.id) else { return }
                cohouse?.users[userId].userId = userInfo.id.uuidString
            }
        },
        quitCohouse: {
            @Shared(.cohouse) var cohouse

            await $cohouse.withLock { $0 = nil }
            // TODO: In the near future, we'll also need to remove user from cohouse associated to it.
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
