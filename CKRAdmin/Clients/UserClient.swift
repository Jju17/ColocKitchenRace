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

enum UserError: Error {
    case failed
    case failedWithError(String)
}

@DependencyClient
struct UserClient {
    var totalUsersCount: @Sendable () async throws -> Result<Int, AuthError>
}

extension UserClient: DependencyKey {
    static let liveValue = Self(
        totalUsersCount: {
            do {
                let countQuery = Firestore.firestore().collection("users").count
                let snapshot = try await countQuery.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                return .failure(.failedWithError(error.localizedDescription))
            }
        }
    )

    static var previewValue: UserClient {
        return .testValue
    }
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
