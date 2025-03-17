//
//  AuthentificationClient.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
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
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> Result<User, AuthError>
    var signOut: () async throws -> Void
    var listenAuthState: @Sendable () throws -> AsyncStream<FirebaseAuth.User?>
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self(
        signIn: { email, password in
            do {
                let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
                let querySnapshot = try await Firestore.firestore()
                                                        .collection("users")
                                                        .whereField("authId", isEqualTo: authDataResult.user.uid)
                                                        .getDocuments()

                guard let loggedUser = try querySnapshot.documents.first?.data(as: User.self)
                else { return .failure(.failed)}

                return .success(loggedUser)
            } catch {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                return .failure(.failedWithError(error.localizedDescription))
            }
        },
        signOut: {
            try Auth.auth().signOut()
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
