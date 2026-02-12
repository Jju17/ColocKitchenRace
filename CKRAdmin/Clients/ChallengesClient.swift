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

struct ChallengeCounts: Equatable {
    var total: Int = 0
    var active: Int = 0
    var next: Int = 0
}

@DependencyClient
struct ChallengeClient {
    var add: @Sendable (_ newChallenge: Challenge) async -> Result<Bool, ChallengeError> = { _ in .success(true) }
    var addAllMockChallenges: @Sendable () async -> Result<Void, ChallengeError> = { .success(()) }
    var getAll: @Sendable () async -> Result<[Challenge], ChallengeError> = { .success([]) }
    var totalChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var activeChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var nextChallengesCount: @Sendable () async -> Result<Int, ChallengeError> = { .success(0) }
    var watchChallengesCounts: @Sendable () -> AsyncStream<ChallengeCounts> = { AsyncStream { $0.finish() } }
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
        addAllMockChallenges: {
            do {
                let db = Firestore.firestore()
                let batch = db.batch()
                for response in Challenge.mockList {
                    let responseRef = db.collection("challenges").document(response.id.uuidString)
                    try batch.setData(from: response, forDocument: responseRef)
                }
                try await batch.commit()
                Logger.challengeResponseLog.log(level: .info, "Successfully added \(ChallengeResponse.mockList.count) mock challenges")
                return .success(())
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "Failed to add mock challenge responses: \(error.localizedDescription)")
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
        getAll: {
            do {
                let querySnapshot = try await Firestore.firestore()
                    .collection("challenges")
                    .order(by: "startDate", descending: false)
                    .getDocuments()
                let documents = querySnapshot.documents
                let allChallenges = documents.compactMap { document in
                    try? document.data(as: Challenge.self)
                }
                return .success(allChallenges)
            } catch {
                return .failure(.unknown(error.localizedDescription))
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
        watchChallengesCounts: {
            AsyncStream { continuation in
                let listener = Firestore.firestore()
                    .collection("challenges")
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            Logger.challengeLog.log(level: .error, "watchChallengesCounts error: \(error.localizedDescription)")
                            return
                        }
                        guard let snapshot else { return }

                        let now = Date()
                        var counts = ChallengeCounts()
                        counts.total = snapshot.documents.count

                        for doc in snapshot.documents {
                            let data = doc.data()
                            guard let startTimestamp = data["startDate"] as? Timestamp,
                                  let endTimestamp = data["endDate"] as? Timestamp
                            else { continue }

                            let startDate = startTimestamp.dateValue()
                            let endDate = endTimestamp.dateValue()

                            if startDate <= now && endDate >= now {
                                counts.active += 1
                            } else if startDate > now {
                                counts.next += 1
                            }
                        }

                        continuation.yield(counts)
                    }
                continuation.onTermination = { _ in listener.remove() }
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
            addAllMockChallenges: { .success(()) },
            getAll: { .success([]) },
            totalChallengesCount: { .success(42) },
            activeChallengesCount: { .success(10) },
            nextChallengesCount: { .success(5) },
            watchChallengesCounts: { AsyncStream { $0.finish() } },
            delete: { _ in }
        )
    }

    static var testValue: ChallengeClient {
        Self(
            add: { _ in .success(true) },
            addAllMockChallenges: { .success(()) },
            getAll: { .success([]) },
            totalChallengesCount: { .success(0) },
            activeChallengesCount: { .success(0) },
            nextChallengesCount: { .success(0) },
            watchChallengesCounts: { AsyncStream { $0.finish() } },
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
