//
//  FirestoreHelpers.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import FirebaseFirestore

// MARK: - Cohouse Helpers

enum FirestoreHelpers {

    /// Fetches a cohouse and its users from Firestore by document reference
    static func fetchCohouseWithUsers(from cohouseRef: DocumentReference) async throws -> Cohouse {
        let firCohouse = try await cohouseRef.getDocument(as: FirestoreCohouse.self)
        let usersSnapshot = try await cohouseRef.collection("users").getDocuments()
        let cohouseUsers = try usersSnapshot.documents.map { try $0.data(as: CohouseUser.self) }
        return firCohouse.toCohouseObject(with: cohouseUsers)
    }

    /// Updates the user's cohouseId in Firestore and local shared state
    static func updateUserCohouseId(_ cohouseId: String?, for userInfo: User) throws {
        var updatedUser = userInfo
        updatedUser.cohouseId = cohouseId
        try Firestore.firestore().collection("users").document(userInfo.id.uuidString).setData(from: updatedUser)
        @Shared(.userInfo) var sharedUserInfo
        $sharedUserInfo.withLock { $0 = updatedUser }
    }
}
