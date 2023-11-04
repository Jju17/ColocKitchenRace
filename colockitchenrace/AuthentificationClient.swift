//
//  AuthentificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/10/2023.
//

import Dependencies
import FirebaseAuth
import Foundation

struct AuthentificationClient {
    var requestAcess: (String, String) async throws  -> AuthDataResult
}

extension AuthentificationClient: DependencyKey {
    static let liveValue = Self { email, password in
        return try await Auth.auth().signIn(withEmail: email, password: password)
    }

    static var previewValue: AuthentificationClient {
        return .testValue
    }
}
