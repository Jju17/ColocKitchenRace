//
//  AuthenticationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import os

// MARK: - Error

enum AuthError: Error, LocalizedError, Equatable {
    case failed
    case failedWithError(String)

    var errorDescription: String? {
        switch self {
        case .failed:
            return "Authentication failed"
        case .failedWithError(let message):
            return message
        }
    }
}

// MARK: - Client Interface

@DependencyClient
struct AuthenticationClient {
    var signUp: @Sendable (_ signupUserData: SignupUser) async throws -> User
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> User
    var signOut: () async throws -> Void
    var deleteAccount: () -> Void
    var updateUser: (_ user: User) async throws -> Void
    var listenAuthState: @Sendable () -> AsyncStream<FirebaseAuth.User?> = { .never }
}

// MARK: - Implementations

extension AuthenticationClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        signUp: { signupUserData in
            @Shared(.userInfo) var userInfo

            let authResult = try await Auth.auth().createUser(
                withEmail: signupUserData.email,
                password: signupUserData.password
            )
            try await authResult.user.sendEmailVerification()

            let newUser = signupUserData.createUser(authId: authResult.user.uid)

            try Firestore.firestore()
                .collection("users")
                .document(newUser.id.uuidString)
                .setData(from: newUser)

            try? await Messaging.messaging().subscribe(toTopic: "all_users")

            $userInfo.withLock { $0 = newUser }
            return newUser
        },
        signIn: { email, password in
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

            let db = Firestore.firestore()
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)

            let snapshot = try await db
                .collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            guard let loggedUser = try snapshot.documents.first?.data(as: User.self) else {
                throw AuthError.failed
            }

            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            $userInfo.withLock { $0 = loggedUser }

            // Auto-load user's cohouse if they have one
            if let cohouseId = loggedUser.cohouseId {
                let cohouseRef = db.collection("cohouses").document(cohouseId)
                if let loaded = try? await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef) {
                    $cohouse.withLock { $0 = loaded }
                }
            }

            return loggedUser
        },
        signOut: {
            try? await Messaging.messaging().unsubscribe(fromTopic: "all_users")
            try Auth.auth().signOut()

            @Shared(.userInfo) var user
            @Shared(.cohouse) var cohouse
            @Shared(.ckrGame) var ckrGame
            @Shared(.news) var news
            @Shared(.challenges) var challenges

            $user.withLock { $0 = nil }
            $cohouse.withLock { $0 = nil }
            $ckrGame.withLock { $0 = nil }
            $news.withLock { $0 = [] }
            $challenges.withLock { $0 = [] }
        },
        deleteAccount: {
            // TODO: Implement account deletion
        },
        updateUser: { updatedUser in
            let docRef = Firestore.firestore()
                .collection("users")
                .document(updatedUser.id.uuidString)
            try docRef.setData(from: updatedUser)

            @Shared(.userInfo) var user
            $user.withLock { $0 = updatedUser }
        },
        listenAuthState: {
            AsyncStream { continuation in
                DispatchQueue.main.async {
                    let _ = Auth.auth().addStateDidChangeListener { _, user in
                        continuation.yield(user)
                    }
                }
            }
        }
    )

    // MARK: Test

    static let testValue = Self(
        signUp: { _ in .mockUser },
        signIn: { _, _ in .mockUser },
        signOut: {},
        deleteAccount: {},
        updateUser: { _ in },
        listenAuthState: { AsyncStream { $0.finish() } }
    )

    // MARK: Preview

    static let previewValue: AuthenticationClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}
