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

@DependencyClient
struct AuthentificationClient {
    var signUp: @Sendable (_ signupUserData: SignupUser) async throws -> Result<User, Error>
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> Result<User, Error>
    var signOut: () -> Void
    var deleteAccount: () -> Void
    var setUser: (_ user: User, _ uid: String) async throws -> Void
    var listenAuthState: @Sendable () throws -> AsyncStream<FirebaseAuth.User?>
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self(
        signUp: { signupUserData in
            do {
                let authDataResult = try await Auth.auth().createUser(withEmail: signupUserData.email, password: signupUserData.password)
                let userId = authDataResult.user.uid
                let newUser = signupUserData.createUser(uid: userId)

                try Firestore.firestore().collection("users").document(userId).setData(from: newUser)
                @Shared(.userInfo) var user
                user = newUser
                return Result(.success(newUser))
            } catch {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                return Result(.failure(error))
            }
        },
        signIn: { email, password in
            do {
                let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
                let loggedUser = try await Firestore.firestore().collection("users").document(authDataResult.user.uid).getDocument(as: User.self)
                @Shared(.userInfo) var user
                user = loggedUser
                return Result(.success(loggedUser))
            } catch {
                return Result(.failure(error))
            }
        },
        signOut: {
            do {
                try Auth.auth().signOut()
                @Shared(.userInfo) var user = nil
            }
            catch { print("already logged out") }
        },
        deleteAccount: {},
        setUser: { newUser, uid in
            let firestore = Firestore.firestore()
            let docRef = firestore.collection("users").document(uid)
            try docRef.setData(from: newUser)
            @Shared(.userInfo) var user
            user = newUser
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
