//
//  AuthentificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import Dependencies
import FirebaseAuth

struct AuthentificationClient {
    var load: () async throws -> AuthDataResult
    var signUp: (String, String, String) async throws -> AuthDataResult
    var signIn: (String, String) async throws -> AuthDataResult
    var signOut: () -> Void
    var deleteAccount: () -> Void
    var fetchUser: () async -> Void
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self(
        load: {
            return try await Auth.auth().createUser(withEmail: "", password: "")
        },
        signUp: { email, password, fullName in
            return try await Auth.auth().createUser(withEmail: email, password: password)
        },
        signIn: { email, password in
            return try await Auth.auth().signIn(withEmail: email, password: password)
        },
        signOut: {},
        deleteAccount: {},
        fetchUser: {}
    )

    static var previewValue: AuthentificationClient {
        return .testValue
    }
}
