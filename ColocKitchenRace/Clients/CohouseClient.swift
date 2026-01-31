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
    case missingUserInfo
    case userNotInCohouse
    case cohouseNotFound
}

@DependencyClient
struct CohouseClient {
    var add: @Sendable (_ newCohouse: Cohouse) async throws -> Void
    var get: @Sendable (_ id: String) async throws -> Cohouse
    var getByCode: @Sendable (_ code: String) async throws -> Cohouse
    var set: @Sendable (_ id: String, _ newCohouse: Cohouse) async throws -> Void
    var setUser: @Sendable (_ user: CohouseUser, _ cohouseId: String) async throws -> Void
    var quitCohouse: @Sendable () async throws -> Void
}

extension CohouseClient: DependencyKey {
    static let liveValue = Self(
        add: { newCohouse in
            @Shared(.cohouse) var currentCohouse
            @Shared(.userInfo) var userInfo

            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(newCohouse.id.uuidString)

            do {
                try cohouseRef.setData(from: newCohouse.toFIRCohouse)

                let usersCollectionRef = cohouseRef.collection("users")
                for user in newCohouse.users {
                    try usersCollectionRef.document(user.id.uuidString).setData(from: user)
                }

                // Update user's cohouseId in Firestore
                if let userInfo {
                    try FirestoreHelpers.updateUserCohouseId(newCohouse.id.uuidString, for: userInfo)
                }

                $currentCohouse.withLock { $0 = newCohouse }
            } catch {
                throw CohouseClientError.failedWithError(error.localizedDescription)
            }
        },
        get: { id in
            @Shared(.cohouse) var currentCohouse
            @Shared(.userInfo) var userInfo

            guard let userInfo else {
                throw CohouseClientError.missingUserInfo
            }

            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(id)

            do {
                let cohouse = try await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef)

                let currentUserId = userInfo.id.uuidString
                let isMember = cohouse.users.contains { $0.userId == currentUserId }

                guard isMember else {
                    throw CohouseClientError.userNotInCohouse
                }

                $currentCohouse.withLock { $0 = cohouse }

                return cohouse
            } catch let error as CohouseClientError {
                throw error
            } catch {
                throw CohouseClientError.failedWithError(error.localizedDescription)
            }
        },
        getByCode: { code in
            let db = Firestore.firestore()

            do {
                let snapshot = try await db
                    .collection("cohouses")
                    .whereField("code", isEqualTo: code)
                    .getDocuments()

                guard let cohouseSnapshot = snapshot.documents.first else {
                    throw CohouseClientError.cohouseNotFound
                }

                return try await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseSnapshot.reference)
            } catch let error as CohouseClientError {
                throw error
            } catch {
                throw CohouseClientError.failedWithError(error.localizedDescription)
            }
        },
        set: { id, newCohouse in
            @Shared(.cohouse) var currentCohouse
            let db = Firestore.firestore()

            do {
                let cohouseRef = db.collection("cohouses").document(id)
                let usersCollectionRef = cohouseRef.collection("users")

                let existingSnapshot = try await usersCollectionRef.getDocuments()
                let existingIds = Set(existingSnapshot.documents.map { $0.documentID })

                let newIds = Set(newCohouse.users.map { $0.id.uuidString })
                let toDelete = existingIds.subtracting(newIds)

                let batch = db.batch()
                try batch.setData(
                    from: newCohouse.toFIRCohouse,
                    forDocument: cohouseRef,
                    merge: false
                )

                for user in newCohouse.users {
                    let userRef = usersCollectionRef.document(user.id.uuidString)
                    try batch.setData(from: user, forDocument: userRef, merge: false)
                }

                for id in toDelete {
                    let ref = usersCollectionRef.document(id)
                    batch.deleteDocument(ref)
                }

                try await batch.commit()

                $currentCohouse.withLock { $0 = newCohouse }
            } catch {
                throw CohouseClientError.failedWithError(error.localizedDescription)
            }
        },
        setUser: { user, cohouseId in
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(cohouseId)
            let usersCollectionRef = cohouseRef.collection("users")

            guard let userInfo else { return }

            var newUser = user
            newUser.userId = userInfo.id.uuidString

            // Set personnal ID to selected user in cohouse
            try usersCollectionRef.document(newUser.id.uuidString).setData(from: newUser, merge: false)
            $cohouse.withLock { cohouse in
                guard let userId = cohouse?.users.index(id: newUser.id) else { return }
                cohouse?.users[userId].userId = userInfo.id.uuidString
            }

            // Update user's cohouseId in Firestore
            try FirestoreHelpers.updateUserCohouseId(cohouseId, for: userInfo)
        },
        quitCohouse: {
            @Shared(.cohouse) var cohouse
            @Shared(.userInfo) var userInfo

            guard let cohouse, let userInfo else { return }

            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(cohouse.id.uuidString)
            let usersCollectionRef = cohouseRef.collection("users")

            let querySnapshot = try await usersCollectionRef.whereField("userId", isEqualTo: userInfo.id.uuidString).getDocuments()
            guard let document = querySnapshot.documents.first else { return }

            try await usersCollectionRef.document(document.documentID).delete()

            // Clear user's cohouseId in Firestore
            try FirestoreHelpers.updateUserCohouseId(nil, for: userInfo)

            $cohouse.withLock { $0 = nil }
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
