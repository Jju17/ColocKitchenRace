//
//  AuthenticationClient.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import AuthenticationServices
import ComposableArchitecture
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import GoogleSignIn
import os
import UIKit

// MARK: - Error

enum AuthError: Error, LocalizedError, Equatable {
    case failed
    case failedWithError(String)
    case accountNotFound
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .failed:
            return "Authentication failed"
        case .failedWithError(let message):
            return message
        case .accountNotFound:
            return "No account found for this email."
        case .invalidCredentials:
            return "Invalid email or password."
        }
    }
}

// MARK: - Client Interface

@DependencyClient
struct AuthenticationClient {
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> User
    var createAccount: @Sendable (_ email: String, _ password: String) async throws -> User
    var signOut: () async throws -> Void
    var deleteAccount: @Sendable () async throws -> Void
    var updateUser: (_ user: User) async throws -> Void
    var resendVerificationEmail: @Sendable () async throws -> Void
    var signInWithGoogle: @Sendable () async throws -> User
    var signInWithApple: @Sendable () async throws -> User
    var sendVerificationEmail: @Sendable (_ newEmail: String) async throws -> Void
    var reloadCurrentUser: @Sendable () async throws -> Bool
    var listenAuthState: @Sendable () -> AsyncStream<FirebaseAuth.User?> = { .never }
}

// MARK: - Implementations

extension AuthenticationClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        signIn: { email, password in
            let db = Firestore.firestore()

            // Try signing in. If the user doesn't exist, throw .accountNotFound
            // so the UI can ask for confirmation before creating an account.
            let authResult: AuthDataResult
            do {
                authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            } catch {
                let errorCode = (error as NSError).code
                // Firebase may return .userNotFound (17011) or .invalidCredential
                // (17004, when email enumeration protection is enabled) for non-existent accounts.
                if errorCode == AuthErrorCode.userNotFound.rawValue {
                    throw AuthError.accountNotFound
                } else if errorCode == AuthErrorCode.invalidCredential.rawValue {
                    throw AuthError.invalidCredentials
                }
                throw error
            }

            // Existing user — find Firestore profile
            let snapshot = try await db
                .collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            let loggedUser: User
            if let existing = try snapshot.documents.first?.data(as: User.self) {
                loggedUser = existing
            } else {
                // Firebase Auth account exists but no Firestore profile (edge case) — create one
                let newUser = User(
                    id: UUID(),
                    authId: authResult.user.uid,
                    authProvider: .email,
                    isSubscribeToNews: false,
                    email: email
                )
                try db.collection("users")
                    .document(newUser.id.uuidString)
                    .setData(from: newUser)
                loggedUser = newUser
            }

            await completeSignIn(loggedUser)
            return loggedUser
        },
        createAccount: { email, password in
            @Shared(.userInfo) var userInfo

            let db = Firestore.firestore()

            let createResult = try await Auth.auth().createUser(withEmail: email, password: password)
            try await createResult.user.sendEmailVerification()

            let newUser = User(
                id: UUID(),
                authId: createResult.user.uid,
                authProvider: .email,
                isSubscribeToNews: false,
                email: email
            )

            try db.collection("users")
                .document(newUser.id.uuidString)
                .setData(from: newUser)

            do {
                try await Messaging.messaging().subscribe(toTopic: CKREnvironment.fcmTopicAllUsers)
            } catch {
                Logger.authLog.error("Failed to subscribe to FCM topic on account creation: \(error)")
            }
            $userInfo.withLock { $0 = newUser }
            return newUser
        },
        signOut: {
            // Unsubscribe from all FCM topics
            do {
                try await Messaging.messaging().unsubscribe(fromTopic: CKREnvironment.fcmTopicAllUsers)
            } catch {
                Logger.authLog.error("Failed to unsubscribe from FCM all_users topic: \(error)")
            }
            // Unsubscribe from edition topic if active
            @Shared(.userInfo) var user
            if let editionId = user?.activeEditionId {
                let editionTopic = CKREnvironment.fcmTopicEdition(editionId)
                do {
                    try await Messaging.messaging().unsubscribe(fromTopic: editionTopic)
                } catch {
                    Logger.authLog.error("Failed to unsubscribe from edition topic: \(error)")
                }
            }
            try Auth.auth().signOut()
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
            @Shared(.userInfo) var user
            @Shared(.cohouse) var cohouse
            @Shared(.ckrGame) var ckrGame
            @Shared(.news) var news
            @Shared(.challenges) var challenges

            guard let userInfo = user else {
                throw AuthError.failedWithError("No user session found")
            }

            // 1. Unsubscribe from FCM topic before account is deleted
            do {
                try await Messaging.messaging().unsubscribe(fromTopic: CKREnvironment.fcmTopicAllUsers)
            } catch {
                Logger.authLog.error("Failed to unsubscribe from FCM topic on delete: \(error)")
            }

            // 2. Call Cloud Function to delete all server-side data
            let functions = Functions.functions(region: "europe-west1")
            _ = try await functions.httpsCallable("deleteAccount").call([
                "userId": userInfo.id.uuidString
            ])

            // 3. Sign out locally (Auth account already deleted server-side)
            do {
                try Auth.auth().signOut()
            } catch {
                Logger.authLog.error("Failed to sign out locally after account deletion: \(error)")
            }

            // 4. Clear all local shared state
            $user.withLock { $0 = nil }
            $cohouse.withLock { $0 = nil }
            $ckrGame.withLock { $0 = nil }
            $news.withLock { $0 = [] }
            $challenges.withLock { $0 = [] }
        },
        updateUser: { updatedUser in
            let docRef = Firestore.firestore()
                .collection("users")
                .document(updatedUser.id.uuidString)
            try docRef.setData(from: updatedUser, merge: true)

            @Shared(.userInfo) var user
            $user.withLock { $0 = updatedUser }
        },
        resendVerificationEmail: {
            guard let user = Auth.auth().currentUser else { throw AuthError.failed }
            try await user.sendEmailVerification()
        },
        signInWithGoogle: {
            // 1. Get the root view controller to present Google Sign-In
            let rootVC = try await MainActor.run {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootVC = windowScene.windows.first?.rootViewController
                else { throw AuthError.failed }
                return rootVC
            }

            // 2. Start Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.failedWithError("Failed to get Google ID token")
            }

            // 3. Create Firebase credential and sign in
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)

            // 4. Find or create user in Firestore
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            let user: User
            if var existing = try snapshot.documents.first?.data(as: User.self) {
                // Backfill authProvider for returning OAuth users
                if existing.authProvider == nil {
                    existing.authProvider = .google
                    try db.collection("users").document(existing.id.uuidString).setData(from: existing)
                }
                user = existing
            } else {
                let parts = (authResult.user.displayName ?? "").split(separator: " ", maxSplits: 1)
                let newUser = User(
                    id: UUID(),
                    authId: authResult.user.uid,
                    authProvider: .google,
                    isSubscribeToNews: false,
                    firstName: String(parts.first ?? ""),
                    lastName: parts.count > 1 ? String(parts[1]) : "",
                    email: authResult.user.email
                )
                try db.collection("users")
                    .document(newUser.id.uuidString)
                    .setData(from: newUser)
                user = newUser
            }

            await completeSignIn(user)
            return user
        },
        signInWithApple: {
            // 1. Run Apple Sign-In flow on the main actor
            let helper = await MainActor.run { AppleSignInHelper() }
            let authorization = try await helper.signIn()
            let nonce = await helper.currentNonce

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8),
                  let nonce
            else { throw AuthError.failedWithError("Failed to get Apple ID token") }

            // 2. Create Firebase credential and sign in
            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            let authResult = try await Auth.auth().signIn(with: credential)

            // 3. Find or create user in Firestore
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users")
                .whereField("authId", isEqualTo: authResult.user.uid)
                .getDocuments()

            let user: User
            if var existing = try snapshot.documents.first?.data(as: User.self) {
                // Backfill authProvider for returning OAuth users
                if existing.authProvider == nil {
                    existing.authProvider = .apple
                    try db.collection("users").document(existing.id.uuidString).setData(from: existing)
                }
                user = existing
            } else {
                // Apple only provides name on first sign-in.
                // Fallback to Firebase displayName if Apple doesn't provide it.
                let appleFirst = appleIDCredential.fullName?.givenName
                let appleLast = appleIDCredential.fullName?.familyName
                let firebaseParts = (authResult.user.displayName ?? "").split(separator: " ", maxSplits: 1)

                let firstName = appleFirst
                    ?? firebaseParts.first.map(String.init)
                    ?? "First name"
                let lastName = appleLast
                    ?? (firebaseParts.count > 1 ? String(firebaseParts[1]) : "Last name")

                let newUser = User(
                    id: UUID(),
                    authId: authResult.user.uid,
                    authProvider: .apple,
                    isSubscribeToNews: false,
                    firstName: firstName,
                    lastName: lastName,
                    email: authResult.user.email
                )
                try db.collection("users")
                    .document(newUser.id.uuidString)
                    .setData(from: newUser)
                user = newUser
            }

            await completeSignIn(user)
            return user
        },
        sendVerificationEmail: { newEmail in
            guard let user = Auth.auth().currentUser else { throw AuthError.failed }
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
        },
        reloadCurrentUser: {
            guard let user = Auth.auth().currentUser else { throw AuthError.failed }
            try await user.reload()
            return Auth.auth().currentUser?.isEmailVerified ?? false
        },
        listenAuthState: {
            AsyncStream { continuation in
                // Use nonisolated(unsafe) to bridge the handle across the
                // concurrency boundary. The handle is set once on the main
                // queue and only read on termination.
                nonisolated(unsafe) var handle: AuthStateDidChangeListenerHandle?

                continuation.onTermination = { _ in
                    if let handle {
                        Auth.auth().removeStateDidChangeListener(handle)
                    }
                }

                DispatchQueue.main.async {
                    handle = Auth.auth().addStateDidChangeListener { _, user in
                        continuation.yield(user)
                    }
                }
            }
        }
    )

    // MARK: - Sign-In Helper

    /// Shared post-sign-in setup: FCM subscription, shared state, demo mode, cohouse loading.
    private static func completeSignIn(_ user: User) async {
        @Shared(.userInfo) var userInfo
        @Shared(.cohouse) var cohouse

        do {
            try await Messaging.messaging().subscribe(toTopic: CKREnvironment.fcmTopicAllUsers)
        } catch {
            Logger.authLog.error("Failed to subscribe to FCM topic: \(error)")
        }
        $userInfo.withLock { $0 = user }

        if user.email == DemoMode.demoEmail {
            DemoMode.seedSharedState(for: user)
            return
        }

        if let cohouseId = user.cohouseId {
            let db = Firestore.firestore()
            let cohouseRef = db.collection("cohouses").document(cohouseId)
            do {
                let loaded = try await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef)
                $cohouse.withLock { $0 = loaded }
            } catch {
                Logger.authLog.error("Failed to load cohouse \(cohouseId) after sign-in: \(error)")
            }
        }
    }

    // MARK: Test

    static let testValue = Self(
        signIn: { _, _ in .mockUser },
        createAccount: { _, _ in .mockUser },
        signOut: {},
        deleteAccount: { },
        updateUser: { _ in },
        resendVerificationEmail: {},
        signInWithGoogle: { .mockUser },
        signInWithApple: { .mockUser },
        sendVerificationEmail: { _ in },
        reloadCurrentUser: { true },
        listenAuthState: { AsyncStream { $0.finish() } }
    )

    // MARK: Preview

    static let previewValue: AuthenticationClient = .testValue
}

// MARK: - Apple Sign-In Helper

@MainActor
final class AppleSignInHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private(set) var currentNonce: String?

    func signIn() async throws -> ASAuthorization {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    // MARK: - Nonce Helpers

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        // 64 characters (power of 2) to avoid modulo bias with UInt8 values
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Registration

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}
