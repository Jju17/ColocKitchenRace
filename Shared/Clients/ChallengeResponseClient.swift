//
//  ChallengeResponseClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 14/05/2025.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import FirebaseFirestore
import FirebaseStorage
import os

enum ChallengeResponseError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

@DependencyClient
struct ChallengeResponseClient {
    var getAll: @Sendable () async -> Result<[ChallengeResponse], ChallengeResponseError> = { .success([]) }
    var getAllForCohouse: @Sendable (_ cohouseId: String) async -> Result<[ChallengeResponse], ChallengeResponseError> = { _ in .success([]) }
    var updateStatus: @Sendable (_ challengeId: UUID, _ cohouseId: String, _ status: ChallengeResponseStatus) async -> Result<Void, ChallengeResponseError> = { _, _, _ in .success(()) }
    var addAllMockChallengeResponses: @Sendable () async -> Result<Void, ChallengeResponseError> = { .success(()) }
    var submit: @Sendable (_ response: ChallengeResponse) async throws -> ChallengeResponse = { $0 }
    var watchStatus: @Sendable (_ challengeId: UUID, _ cohouseId: String) -> AsyncStream<ChallengeResponseStatus> = { _,_  in AsyncStream { $0.finish() } }
}

extension ChallengeResponseClient: DependencyKey {
    static let liveValue = Self(
        getAll: {
            do {
                // New scheme: Read every sub-collections "responses" via collectionGroup
                let querySnapshot = try await Firestore.firestore()
                    .collectionGroup("responses")
                    .getDocuments()
                let documents = querySnapshot.documents
                let responses = documents.compactMap { document in
                    try? document.data(as: ChallengeResponse.self)
                }
                return .success(responses)
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "\(error.localizedDescription)")
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
        getAllForCohouse: { cohouseId in
            do {
                // Filter by cohouseId directly on the collection group
                let querySnapshot = try await Firestore.firestore()
                    .collectionGroup("responses")
                    .whereField("cohouseId", isEqualTo: cohouseId)
                    .getDocuments()
                let documents = querySnapshot.documents
                let responses = documents.compactMap { document in
                    try? document.data(as: ChallengeResponse.self)
                }
                return .success(responses)
            } catch let error as NSError {
                Logger.challengeResponseLog.log(level: .fault, "\(error.localizedDescription)")
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
                Logger.challengeResponseLog.log(level: .fault, "\(error.localizedDescription)")
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
                Logger.challengeResponseLog.log(level: .info, "Successfully added \(ChallengeResponse.mockList.count) mock challenge responses")
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
        submit: { response in
            do {
                let db = Firestore.firestore()
                // New imbricked scheme: /challenges/{challengeId}/responses/{cohouseId}
                let doc = db.collection("challenges")
                    .document(response.challengeId.uuidString)
                    .collection("responses")
                    .document(response.cohouseId)

                try doc.setData(from: response, merge: true)
                try await doc.updateData(["serverTS": FieldValue.serverTimestamp()])
                return response

            } catch let error as NSError {
                switch error.code {
                    case FirestoreErrorCode.unavailable.rawValue:
                        throw ChallengeResponseError.networkError
                    case FirestoreErrorCode.permissionDenied.rawValue:
                        throw ChallengeResponseError.permissionDenied
                    default:
                        throw ChallengeResponseError.unknown(error.localizedDescription)
                }
            }
        },
        watchStatus: { challengeId, cohouseId in
            let db = Firestore.firestore()
            let doc = db.collection("challenges")
                .document(challengeId.uuidString)
                .collection("responses")
                .document(cohouseId)

            return AsyncStream { continuation in
                let listener = doc.addSnapshotListener { snap, _ in
                    guard
                        let snap,
                        let resp = try? snap.data(as: ChallengeResponse.self)
                    else { return }
                    continuation.yield(resp.status)
                }
                continuation.onTermination = { _ in listener.remove() }
            }
        }
    )

    static var previewValue: ChallengeResponseClient {
        Self(
            getAll: { .success(ChallengeResponse.mockList) },
            getAllForCohouse: { cohouseId in
                .success(ChallengeResponse.mockList.filter { $0.cohouseId == cohouseId })
            },
            updateStatus: { _, _, _ in .success(()) },
            addAllMockChallengeResponses: { .success(()) },
            submit: { $0 },
            watchStatus: { _, _ in AsyncStream { $0.finish() } }
        )
    }

    static var testValue: ChallengeResponseClient {
        Self(
            getAll: { .success([]) },
            getAllForCohouse: { _ in .success([]) },
            updateStatus: { _, _, _ in .success(()) },
            addAllMockChallengeResponses: { .success(()) },
            submit: { $0 },
            watchStatus: { _, _ in AsyncStream { $0.finish() } }
        )
    }
}

extension DependencyValues {
    var challengeResponseClient: ChallengeResponseClient {
        get { self[ChallengeResponseClient.self] }
        set { self[ChallengeResponseClient.self] = newValue }
    }
}
