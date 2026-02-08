//
//  CohouseClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import FirebaseFirestore
import os

enum CohouseError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

@DependencyClient
struct CohouseClient {
    var totalCohousesCount: @Sendable () async -> Result<Int, CohouseError> = { .success(0) }
}

extension CohouseClient: DependencyKey {
    static let liveValue = Self(
        totalCohousesCount: {
            do {
                let db = Firestore.firestore()
                let collectionRef = db.collection("cohouses")
                let snapshot = try await collectionRef.count.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch let error as NSError {
                Logger.cohouseLog.log(level: .fault, "\(error.localizedDescription)")
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

    static var previewValue: CohouseClient {
        Self(
            totalCohousesCount: { .success(42) }
        )
    }

    static var testValue: CohouseClient {
        Self(
            totalCohousesCount: { .success(0) }
        )
    }
}

extension DependencyValues {
    var cohouseClient: CohouseClient {
        get { self[CohouseClient.self] }
        set { self[CohouseClient.self] = newValue }
    }
}
