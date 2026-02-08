//
//  CohouseClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/06/2024.
//

import ComposableArchitecture
import FirebaseFirestore

// MARK: - Error

enum CohouseClientError: Error {
    case failed
    case failedWithError(String)
    case missingUserInfo
    case userNotInCohouse
    case cohouseNotFound
}

// MARK: - Client Interface

@DependencyClient
struct CohouseClient {
    var add: @Sendable (_ newCohouse: Cohouse) async throws -> Void
    var get: @Sendable (_ id: String) async throws -> Cohouse
    var getByCode: @Sendable (_ code: String) async throws -> Cohouse
    var set: @Sendable (_ id: String, _ newCohouse: Cohouse) async throws -> Void
    var setUser: @Sendable (_ user: CohouseUser, _ cohouseId: String) async throws -> Void
    var quitCohouse: @Sendable () async throws -> Void
}

// MARK: - Implementations

extension CohouseClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        add: { newCohouse in
            @Shared(.cohouse) var currentCohouse
            @Shared(.userInfo) var userInfo

            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(newCohouse.id.uuidString)

            do {
                try cohouseRef.setData(from: newCohouse.toFIRCohouse)

                let usersRef = cohouseRef.collection("users")
                for user in newCohouse.users {
                    try usersRef.document(user.id.uuidString).setData(from: user)
                }

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

                guard cohouse.users.contains(where: { $0.userId == userInfo.id.uuidString }) else {
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

                guard let document = snapshot.documents.first else {
                    throw CohouseClientError.cohouseNotFound
                }

                return try await FirestoreHelpers.fetchCohouseWithUsers(from: document.reference)
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
                let usersRef = cohouseRef.collection("users")

                // Detect deleted users
                let existingSnapshot = try await usersRef.getDocuments()
                let existingIds = Set(existingSnapshot.documents.map { $0.documentID })
                let newIds = Set(newCohouse.users.map { $0.id.uuidString })
                let toDelete = existingIds.subtracting(newIds)

                // Batch write: update cohouse + users + delete removed users
                let batch = db.batch()

                try batch.setData(from: newCohouse.toFIRCohouse, forDocument: cohouseRef, merge: false)

                for user in newCohouse.users {
                    try batch.setData(from: user, forDocument: usersRef.document(user.id.uuidString), merge: false)
                }

                for deletedId in toDelete {
                    batch.deleteDocument(usersRef.document(deletedId))
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

            guard let userInfo else { return }

            let db = Firestore.firestore()
            let usersRef = db.collection("cohouses").document(cohouseId).collection("users")

            var newUser = user
            newUser.userId = userInfo.id.uuidString

            try usersRef.document(newUser.id.uuidString).setData(from: newUser, merge: false)

            $cohouse.withLock { cohouse in
                guard let index = cohouse?.users.index(id: newUser.id) else { return }
                cohouse?.users[index].userId = userInfo.id.uuidString
            }

            try FirestoreHelpers.updateUserCohouseId(cohouseId, for: userInfo)
        },
        quitCohouse: {
            @Shared(.cohouse) var cohouse
            @Shared(.userInfo) var userInfo

            guard let cohouse, let userInfo else { return }

            let db = Firestore.firestore()
            let usersRef = db.collection("cohouses").document(cohouse.id.uuidString).collection("users")

            let snapshot = try await usersRef
                .whereField("userId", isEqualTo: userInfo.id.uuidString)
                .getDocuments()

            guard let document = snapshot.documents.first else { return }

            try await usersRef.document(document.documentID).delete()
            try FirestoreHelpers.updateUserCohouseId(nil, for: userInfo)

            $cohouse.withLock { $0 = nil }
        }
    )

    // MARK: Test

    static let testValue = Self(
        add: { _ in },
        get: { _ in .mock },
        getByCode: { _ in .mock },
        set: { _, _ in },
        setUser: { _, _ in },
        quitCohouse: {}
    )

    // MARK: Preview

    static let previewValue: CohouseClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var cohouseClient: CohouseClient {
        get { self[CohouseClient.self] }
        set { self[CohouseClient.self] = newValue }
    }
}
