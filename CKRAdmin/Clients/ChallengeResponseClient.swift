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
import os

enum ChallengeResponseError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

@DependencyClient
struct ChallengeResponseClient {
    var getAll: @Sendable () async -> Result<[ChallengeResponse], ChallengeResponseError> = { .success([]) }
    var updateStatus: @Sendable (UUID, ChallengeResponseStatus) async -> Result<Void, ChallengeResponseError> = { _, _ in .success(()) }
    var addAllMockChallenges: @Sendable () async -> Result<Void, ChallengeResponseError> = { .success(()) }
}

extension ChallengeResponseClient: DependencyKey {
    static let liveValue = Self(
        getAll: {
            do {
                let querySnapshot = try await Firestore.firestore().collection("challengeResponses").getDocuments()
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
        updateStatus: { responseId, status in
            do {
                try await Firestore.firestore()
                    .collection("challengeResponses")
                    .document(responseId.uuidString)
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
        addAllMockChallenges: {
            do {
                let db = Firestore.firestore()
                let batch = db.batch()
                for response in ChallengeResponse.mockList {
                    let responseRef = db.collection("challengeResponses").document(response.id.uuidString)
                    try batch.setData(from: response, forDocument: responseRef)
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
        }
    )

    static var previewValue: ChallengeResponseClient {
        Self(
            getAll: { .success(ChallengeResponse.mockList) },
            updateStatus: { _, _ in .success(()) },
            addAllMockChallenges: { .success(()) }
        )
    }

    static var testValue: ChallengeResponseClient {
        Self(
            getAll: { .success([]) },
            updateStatus: { _, _ in .success(()) },
            addAllMockChallenges: { .success(()) }
        )
    }
}

extension DependencyValues {
    var challengeResponseClient: ChallengeResponseClient {
        get { self[ChallengeResponseClient.self] }
        set { self[ChallengeResponseClient.self] = newValue }
    }
}
