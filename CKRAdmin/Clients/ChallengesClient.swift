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
    var add: @Sendable (_ newChallenge: Challenge) async -> Result<Bool, ChallengeError> = { _ in .success(true) }
    var getAll: @Sendable () async -> Result<[Challenge], Error> = { .success([]) }
    var totalChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var activeChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var nextChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var delete: (UUID) async throws -> Void
}

extension ChallengeClient: DependencyKey {
    static let liveValue = Self(
        add: { newChallenge in
            do {
                let challengeRef = Firestore.firestore().collection("challenges").document(newChallenge.id.uuidString)
                try challengeRef.setData(from: newChallenge)
                return .success(true)
            } catch {
                return .failure(.unknown(error.localizedDescription))
            }
        },
        getAll: {
            do {
                let querySnapshot = try await Firestore.firestore().collection("challenges").getDocuments()
                let documents = querySnapshot.documents
                let allChallenges = documents.compactMap { document in
                    try? document.data(as: Challenge.self)
                }
                return .success(allChallenges)
            } catch {
                return .failure(error)
            }
        },
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
        },
        delete: { id in
            let db = Firestore.firestore()
            try await db.collection("challenges").document(id.uuidString).delete()
        }
    )

    static var previewValue: ChallengeClient {
        Self(
            add: { _ in .success(true) },
            getAll: { .success([]) },
            totalChallengesCount: { .success(42) },
            activeChallengesCount: { .success(10) },
            nextChallengesCount: { .success(5) },
            delete: { _ in }
        )
    }

    static var testValue: ChallengeClient {
        Self(
            add: { _ in .success(true) },
            getAll: { .success([]) },
            totalChallengesCount: { .success(0) },
            activeChallengesCount: { .success(0) },
            nextChallengesCount: { .success(0) },
            delete: { _ in }
        )
    }
}

extension DependencyValues {
    var challengeClient: ChallengeClient {
        get { self[ChallengeClient.self] }
        set { self[ChallengeClient.self] = newValue }
    }
}
