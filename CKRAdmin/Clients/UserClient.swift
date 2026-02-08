//
//  UserClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import FirebaseFirestore
import os

enum UserError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

@DependencyClient
struct UserClient {
    var totalUsersCount: @Sendable () async -> Result<Int, UserError> = { .success(0) }
}

extension UserClient: DependencyKey {
    static let liveValue = Self(
        totalUsersCount: {
            do {
                let countQuery = Firestore.firestore().collection("users").count
                let snapshot = try await countQuery.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch let error as NSError {
                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                switch error.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    return .failure(.networkError)
                case FirestoreErrorCode.permissionDenied.rawValue:
                    return .failure(.permissionDenied)
                default:
                    return .failure(.unknown(error.localizedDescription))
                }
            }
        }
    )

    static var previewValue: UserClient {
        Self(
            totalUsersCount: { .success(42) }
        )
    }

    static var testValue: UserClient {
        Self(
            totalUsersCount: { .success(0) }
        )
    }
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
