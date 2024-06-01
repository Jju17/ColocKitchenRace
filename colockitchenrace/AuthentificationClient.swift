//
//  AuthentificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import Dependencies
import DependenciesMacros
import FirebaseAuth

@DependencyClient
struct AuthentificationClient {
    var load: () async throws -> User
    var signUp: @Sendable (_ email: String, _ password: String) async throws -> Result<User, Error>
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> Result<User, Error>
    var signOut: () -> Void
    var deleteAccount: () -> Void
    var fetchUser: () async -> Void
    var listenAuthState: @Sendable () throws -> AsyncStream<FirebaseAuth.User?>
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self(
        load: {
            return User(id: UUID())
        },
        signUp: { email, password in
            do {
                let authDataResult = try await Auth.auth().createUser(withEmail: email, password: password)
                let newUser = User(
                    id: UUID(),
                    uid: authDataResult.user.uid,
                    displayName: authDataResult.user.displayName ?? "",
                    phoneNumber: authDataResult.user.phoneNumber ?? "",
                    email: authDataResult.user.email
                )
                return Result(.success(newUser))
            } catch {
                return Result(.failure(error))
            }
        },
        signIn: { email, password in
            do {
                let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
                let newUser = User(
                    id: UUID(),
                    uid: authDataResult.user.uid,
                    displayName: authDataResult.user.displayName ?? "",
                    phoneNumber: authDataResult.user.phoneNumber ?? "",
                    email: authDataResult.user.email
                )
                return Result(.success(newUser))
            } catch {
                return Result(.failure(error))
            }
        },
        signOut: {
            do {
                try Auth.auth().signOut()
            }
            catch { print("already logged out") }
        },
        deleteAccount: {},
        fetchUser: {}, 
        listenAuthState: {
            return AsyncStream { continuation in
                DispatchQueue.main.async {
                    let handle = Auth.auth().addStateDidChangeListener { (auth, user) in
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
