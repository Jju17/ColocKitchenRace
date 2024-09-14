//
//  AuthentificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import FirebaseAuth
import FirebaseFirestore
import os

enum AuthError: Error {
    case failed
    case failedWithError(String)
}

@DependencyClient
struct AuthentificationClient {
    var signUp: @Sendable (_ signupUserData: SignupUser) async throws -> Result<User, Error>
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> Result<User, AuthError>
    var signOut: () async throws -> Void
    var deleteAccount: () -> Void
    var setUser: (_ user: User, _ uid: String) async throws -> Void
    var listenAuthState: @Sendable () throws -> AsyncStream<FirebaseAuth.User?>
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self(
        signUp: { signupUserData in
            do {
                @Shared(.userInfo) var userInfo

                let authDataResult = try await Auth.auth().createUser(withEmail: signupUserData.email, password: signupUserData.password)
                let authId = authDataResult.user.uid
                let newUser = signupUserData.createUser(authId: authId)

                try Firestore.firestore().collection("users").document(newUser.id.uuidString).setData(from: newUser)

                await $userInfo.withLock { $0 = newUser }
                return Result(.success(newUser))
            } catch {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                return Result(.failure(error))
            }
        },
        signIn: { email, password in
            do {
                @Shared(.userInfo) var userInfo

                let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
                let querySnapshot = try await Firestore.firestore()
                                                        .collection("users")
                                                        .whereField("authId", isEqualTo: authDataResult.user.uid)
                                                        .getDocuments()

                guard let loggedUser = try querySnapshot.documents.first?.data(as: User.self)
                else { return .failure(.failed)}

                await $userInfo.withLock { $0 = loggedUser }
                return .success(loggedUser)
            } catch {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                return .failure(.failedWithError(error.localizedDescription))
            }
        },
        signOut: {
            try Auth.auth().signOut()
            @Shared(.userInfo) var user
            @Shared(.cohouse) var cohouse
            @Shared(.globalInfos) var globalInfos
            @Shared(.news) var news
            @Shared(.challenges) var challenges

            await $user.withLock { $0 = nil }
            await $cohouse.withLock { $0 = nil }
            await $globalInfos.withLock { $0 = nil }
            await $news.withLock { $0 = [] }
            await $challenges.withLock { $0 = [] }
        },
        deleteAccount: {},
        setUser: { newUser, uid in
            let firestore = Firestore.firestore()
            let docRef = firestore.collection("users").document(uid)
            try docRef.setData(from: newUser)
            @Shared(.userInfo) var user
            await $user.withLock { user in
                user = newUser
            }
        },
        listenAuthState: {
            return AsyncStream { continuation in
                DispatchQueue.main.async {
                    let _ = Auth.auth().addStateDidChangeListener { (auth, user) in
                        continuation.yield(user)
                    }
                }
            }
        }
    )

    static var previewValue: AuthentificationClient {
        return .testValue
    }
}

extension DependencyValues {
    var authentificationClient: AuthentificationClient {
        get { self[AuthentificationClient.self] }
        set { self[AuthentificationClient.self] = newValue }
    }
}
