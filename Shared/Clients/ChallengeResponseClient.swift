//
//  ChallengeResponseClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 14/05/2025.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseStorage
import os

// MARK: - Error

enum ChallengeResponseError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)

    init(from nsError: NSError) {
        switch nsError.code {
        case FirestoreErrorCode.unavailable.rawValue:
            self = .networkError
        case FirestoreErrorCode.permissionDenied.rawValue:
            self = .permissionDenied
        default:
            self = .unknown(nsError.localizedDescription)
        }
    }
}

// MARK: - Client Interface

@DependencyClient
struct ChallengeResponseClient {
    var getAll: @Sendable () async -> Result<[ChallengeResponse], ChallengeResponseError> = { .success([]) }
    var getAllForCohouse: @Sendable (_ cohouseId: String) async -> Result<[ChallengeResponse], ChallengeResponseError> = { _ in .success([]) }
    var updateStatus: @Sendable (_ challengeId: UUID, _ cohouseId: String, _ status: ChallengeResponseStatus) async -> Result<Void, ChallengeResponseError> = { _, _, _ in .success(()) }
    var addAllMockChallengeResponses: @Sendable () async -> Result<Void, ChallengeResponseError> = { .success(()) }
    var submit: @Sendable (_ response: ChallengeResponse) async throws -> ChallengeResponse = { $0 }
    var watchStatus: @Sendable (_ challengeId: UUID, _ cohouseId: String) -> AsyncStream<ChallengeResponseStatus> = { _, _ in AsyncStream { $0.finish() } }
    var watchAllValidatedResponses: @Sendable () -> AsyncStream<[ChallengeResponse]> = { AsyncStream { $0.finish() } }
}

// MARK: - Implementations

extension ChallengeResponseClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        getAll: {
            do {
                let snapshot = try await Firestore.firestore()
                    .collectionGroup("responses")
                    .getDocuments()

                let responses = snapshot.documents.compactMap { try? $0.data(as: ChallengeResponse.self) }
                return .success(responses)
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "getAll failed: \(error.localizedDescription)")
                return .failure(ChallengeResponseError(from: error))
            }
        },
        getAllForCohouse: { cohouseId in
            do {
                let snapshot = try await Firestore.firestore()
                    .collectionGroup("responses")
                    .whereField("cohouseId", isEqualTo: cohouseId)
                    .getDocuments()

                let responses = snapshot.documents.compactMap { try? $0.data(as: ChallengeResponse.self) }
                return .success(responses)
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "getAllForCohouse failed: \(error.localizedDescription)")
                return .failure(ChallengeResponseError(from: error))
            }
        },
        updateStatus: { challengeId, cohouseId, status in
            do {
                try await Firestore.firestore()
                    .collection("challenges")
                    .document(challengeId.uuidString)
                    .collection("responses")
                    .document(cohouseId)
                    .updateData(["status": status.rawValue])
                return .success(())
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "updateStatus failed: \(error.localizedDescription)")
                return .failure(ChallengeResponseError(from: error))
            }
        },
        addAllMockChallengeResponses: {
            do {
                let db = Firestore.firestore()
                let batch = db.batch()

                for response in ChallengeResponse.mockList {
                    let doc = db.collection("challenges")
                        .document(response.challengeId.uuidString)
                        .collection("responses")
                        .document(response.cohouseId)
                    try batch.setData(from: response, forDocument: doc, merge: true)
                }

                try await batch.commit()
                Logger.challengeResponseLog.log(level: .info, "Added \(ChallengeResponse.mockList.count) mock responses")
                return .success(())
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "addAllMock failed: \(error.localizedDescription)")
                return .failure(ChallengeResponseError(from: error))
            }
        },
        submit: { response in
            do {
                let db = Firestore.firestore()
                let doc = db.collection("challenges")
                    .document(response.challengeId.uuidString)
                    .collection("responses")
                    .document(response.cohouseId)

                try doc.setData(from: response, merge: true)
                try await doc.updateData(["serverTS": FieldValue.serverTimestamp()])
                return response
            } catch let error as NSError {
                throw ChallengeResponseError(from: error)
            }
        },
        watchStatus: { challengeId, cohouseId in
            let doc = Firestore.firestore()
                .collection("challenges")
                .document(challengeId.uuidString)
                .collection("responses")
                .document(cohouseId)

            return AsyncStream { continuation in
                let listener = doc.addSnapshotListener { snap, _ in
                    guard let snap, let resp = try? snap.data(as: ChallengeResponse.self) else { return }
                    continuation.yield(resp.status)
                }
                continuation.onTermination = { _ in listener.remove() }
            }
        },
        watchAllValidatedResponses: {
            let query = Firestore.firestore()
                .collectionGroup("responses")
                .whereField("status", isEqualTo: ChallengeResponseStatus.validated.rawValue)

            return AsyncStream { continuation in
                let listener = query.addSnapshotListener { snap, error in
                    if let error {
                        Logger.challengeResponseLog.log(level: .error, "watchAllValidatedResponses error: \(error.localizedDescription)")
                        continuation.yield([])
                        return
                    }
                    guard let snap else {
                        continuation.yield([])
                        return
                    }
                    let responses = snap.documents.compactMap { try? $0.data(as: ChallengeResponse.self) }
                    continuation.yield(responses)
                }
                continuation.onTermination = { _ in listener.remove() }
            }
        }
    )

    // MARK: Test

    static let testValue = Self(
        getAll: { .success([]) },
        getAllForCohouse: { _ in .success([]) },
        updateStatus: { _, _, _ in .success(()) },
        addAllMockChallengeResponses: { .success(()) },
        submit: { $0 },
        watchStatus: { _, _ in AsyncStream { $0.finish() } },
        watchAllValidatedResponses: { AsyncStream { $0.finish() } }
    )

    // MARK: Preview

    static let previewValue = Self(
        getAll: { .success(ChallengeResponse.mockList) },
        getAllForCohouse: { cohouseId in
            .success(ChallengeResponse.mockList.filter { $0.cohouseId == cohouseId })
        },
        updateStatus: { _, _, _ in .success(()) },
        addAllMockChallengeResponses: { .success(()) },
        submit: { $0 },
        watchStatus: { _, _ in AsyncStream { $0.finish() } },
        watchAllValidatedResponses: {
            AsyncStream { continuation in
                continuation.yield(ChallengeResponse.mockList.filter { $0.status == .validated })
                continuation.finish()
            }
        }
    )
}

// MARK: - Registration

extension DependencyValues {
    var challengeResponseClient: ChallengeResponseClient {
        get { self[ChallengeResponseClient.self] }
        set { self[ChallengeResponseClient.self] = newValue }
    }
}
