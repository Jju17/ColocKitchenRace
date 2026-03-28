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
    var verifyAdmin: @Sendable (_ uid: String) async throws -> AdminRole? = { _ in nil }
    var listenAuthState: @Sendable () -> AsyncStream<FirebaseAuth.User?> = { .never }
}

// MARK: - Implementations

extension AuthenticationClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        signIn: { email, password in
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)

            // Force-refresh the ID token so that custom claims (e.g. admin: true)
            // are available immediately for Firestore security rules evaluation.
            let tokenResult = try await authResult.user.getIDTokenResult(forcingRefresh: true)

            guard tokenResult.claims["admin"] as? Bool == true else {
                try Auth.auth().signOut()
                throw AuthError.notAdmin
            }

            let snapshot = try await Firestore.firestore()
                .collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            guard let loggedUser = try snapshot.documents.first?.data(as: User.self) else {
                throw AuthError.failed
            }

            return loggedUser
        },
        signOut: {
            try Auth.auth().signOut()
        },
        verifyAdmin: { uid in
            // Force-refresh token to pick up custom claims (role, admin)
            guard let currentUser = Auth.auth().currentUser else {
                return nil
            }
            let tokenResult = try await currentUser.getIDTokenResult(forcingRefresh: true)
            if let role = tokenResult.claims["role"] as? String {
                return AdminRole(rawValue: role)
            }
            // Legacy fallback
            if tokenResult.claims["admin"] as? Bool == true {
                return .superAdmin
            }
            return nil
        },
        listenAuthState: {
            let (stream, continuation) = AsyncStream.makeStream(of: FirebaseAuth.User?.self, bufferingPolicy: .bufferingNewest(1))

            nonisolated(unsafe) var handle: AuthStateDidChangeListenerHandle?

            handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user)
            }

            continuation.onTermination = { _ in
                if let handle {
                    Auth.auth().removeStateDidChangeListener(handle)
                }
            }

            return stream
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
