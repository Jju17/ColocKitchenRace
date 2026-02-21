//
//  AuthenticationClient.swift
//  colockitchenrace
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

    var errorDescription: String? {
        switch self {
        case .failed:
            return "Authentication failed"
        case .failedWithError(let message):
            return message
        case .accountNotFound:
            return "No account found for this email."
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
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

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
                if errorCode == AuthErrorCode.userNotFound.rawValue
                    || errorCode == AuthErrorCode.invalidCredential.rawValue {
                    throw AuthError.accountNotFound
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

            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            $userInfo.withLock { $0 = loggedUser }

            // Demo mode: seed all @Shared with mock data and skip Firestore cohouse loading
            if loggedUser.email == DemoMode.demoEmail {
                DemoMode.seedSharedState(for: loggedUser)
                return loggedUser
            }

            // Auto-load user's cohouse if they have one
            if let cohouseId = loggedUser.cohouseId {
                let cohouseRef = db.collection("cohouses").document(cohouseId)
                if let loaded = try? await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef) {
                    $cohouse.withLock { $0 = loaded }
                }
            }

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

            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            $userInfo.withLock { $0 = newUser }
            return newUser
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
            @Shared(.userInfo) var user
            @Shared(.cohouse) var cohouse
            @Shared(.ckrGame) var ckrGame
            @Shared(.news) var news
            @Shared(.challenges) var challenges

            guard let userInfo = user else {
                throw AuthError.failedWithError("No user session found")
            }

            // 1. Unsubscribe from FCM topic before account is deleted
            try? await Messaging.messaging().unsubscribe(fromTopic: "all_users")

            // 2. Call Cloud Function to delete all server-side data
            let functions = Functions.functions(region: "europe-west1")
            _ = try await functions.httpsCallable("deleteAccount").call([
                "userId": userInfo.id.uuidString
            ])

            // 3. Sign out locally (Auth account already deleted server-side)
            try? Auth.auth().signOut()

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
            try docRef.setData(from: updatedUser)

            @Shared(.userInfo) var user
            $user.withLock { $0 = updatedUser }
        },
        resendVerificationEmail: {
            guard let user = Auth.auth().currentUser else { throw AuthError.failed }
            try await user.sendEmailVerification()
        },
        signInWithGoogle: {
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

            // 1. Get the root view controller to present Google Sign-In
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = await windowScene.windows.first?.rootViewController
            else { throw AuthError.failed }

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

            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            $userInfo.withLock { $0 = user }

            // Auto-load user's cohouse if they have one
            if let cohouseId = user.cohouseId {
                let cohouseRef = db.collection("cohouses").document(cohouseId)
                if let loaded = try? await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef) {
                    $cohouse.withLock { $0 = loaded }
                }
            }

            return user
        },
        signInWithApple: {
            @Shared(.userInfo) var userInfo
            @Shared(.cohouse) var cohouse

            // 1. Run Apple Sign-In flow on the main actor
            let helper = await MainActor.run { AppleSignInHelper() }
            let authorization = try await helper.signIn()

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8),
                  let nonce = helper.currentNonce
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

            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            $userInfo.withLock { $0 = user }

            // Auto-load user's cohouse if they have one
            if let cohouseId = user.cohouseId {
                let cohouseRef = db.collection("cohouses").document(cohouseId)
                if let loaded = try? await FirestoreHelpers.fetchCohouseWithUsers(from: cohouseRef) {
                    $cohouse.withLock { $0 = loaded }
                }
            }

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

final class AppleSignInHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, @unchecked Sendable {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    nonisolated(unsafe) private(set) var currentNonce: String?

    @MainActor
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
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    // MARK: - Nonce Helpers

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
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
