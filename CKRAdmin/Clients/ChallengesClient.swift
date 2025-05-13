//
//  ChallengesClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import FirebaseFirestore
import os

enum ChallengeError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

@DependencyClient
struct ChallengeClient {
    var totalChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var activeChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var nextChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
}

extension ChallengeClient: DependencyKey {
    static let liveValue = Self(
        totalChallengesCount: {
            do {
                let db = Firestore.firestore()
                let collectionRef = db.collection("challenges")
                let snapshot = try await collectionRef.count.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch let error as NSError {
                Logger.challengeLog.log(level: .fault, "\(error.localizedDescription)")
                switch error.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    return .failure(.networkError)
                case FirestoreErrorCode.permissionDenied.rawValue:
                    return .failure(.permissionDenied)
                default:
                    return .failure(.unknown(error.localizedDescription))
                }
            }
        },
        activeChallengesCount: {
            do {
                let db = Firestore.firestore()
                let currentDate = Timestamp(date: Date())
                let collectionRef = db.collection("challenges")
                    .whereField("startDate", isLessThanOrEqualTo: currentDate)
                    .whereField("endDate", isGreaterThanOrEqualTo: currentDate)
                let snapshot = try await collectionRef.count.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch let error as NSError {
                Logger.challengeLog.log(level: .fault, "\(error.localizedDescription)")
                switch error.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    return .failure(.networkError)
                case FirestoreErrorCode.permissionDenied.rawValue:
                    return .failure(.permissionDenied)
                default:
                    return .failure(.unknown(error.localizedDescription))
                }
            }
        },
        nextChallengesCount: {
            do {
                let db = Firestore.firestore()
                let collectionRef = db.collection("challenges")
                    .whereField("startDate", isGreaterThan: Timestamp(date: Date()))
                let snapshot = try await collectionRef.count.getAggregation(source: .server)
                return .success(Int(truncating: snapshot.count))
            } catch let error as NSError {
                Logger.challengeLog.log(level: .fault, "\(error.localizedDescription)")
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

    static var previewValue: ChallengeClient {
        Self(
            totalChallengesCount: { .success(42) },
            activeChallengesCount: { .success(10) },
            nextChallengesCount: { .success(5) }
        )
    }

    static var testValue: ChallengeClient {
        Self(
            totalChallengesCount: { .success(0) },
            activeChallengesCount: { .success(0) },
            nextChallengesCount: { .success(0) }
        )
    }
}

extension DependencyValues {
    var challengeClient: ChallengeClient {
        get { self[ChallengeClient.self] }
        set { self[ChallengeClient.self] = newValue }
    }
}
