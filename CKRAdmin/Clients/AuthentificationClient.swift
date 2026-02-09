//
//  AuthenticationClient.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import DependenciesMacros
import FirebaseAuth
import FirebaseFirestore
import os

// MARK: - Error

enum AuthError: Error, LocalizedError {
    case failed
    case failedWithError(String)
    case notAdmin

    var errorDescription: String? {
        switch self {
        case .failed:
            return "Authentication failed."
        case .failedWithError(let message):
            return message
        case .notAdmin:
            return "Access denied. This app is reserved for administrators."
        }
    }
}

// MARK: - Client Interface

@DependencyClient
struct AuthenticationClient {
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> User
    var signOut: () async throws -> Void
    var listenAuthState: @Sendable () -> AsyncStream<FirebaseAuth.User?> = { .never }
}

// MARK: - Implementations

extension AuthenticationClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        signIn: { email, password in
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)

            let snapshot = try await Firestore.firestore()
                .collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            guard let loggedUser = try snapshot.documents.first?.data(as: User.self) else {
                throw AuthError.failed
            }

            guard loggedUser.isAdmin else {
                try Auth.auth().signOut()
                throw AuthError.notAdmin
            }

            return loggedUser
        },
        signOut: {
            try Auth.auth().signOut()
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
