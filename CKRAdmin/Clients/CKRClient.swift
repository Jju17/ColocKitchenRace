//
//  CKRClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import ComposableArchitecture
import FirebaseFirestore

enum CKRError: Error, Equatable {
    case networkError
    case permissionDenied
    case notFound
    case unknown(String)

    static func fromFirestoreError(_ error: Error) -> CKRError {
        switch (error as NSError).code {
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.notFound.rawValue:
                return .notFound
            case FirestoreErrorCode.unavailable.rawValue:
                return .networkError
            default:
                return .unknown(error.localizedDescription)
        }
    }
}

@DependencyClient
struct CKRClient {
    var newGame: (_ newGame: CKRGame) -> Result<Bool, CKRError> = { _ in .success(true) }
    var getGame: @Sendable () async -> Result<CKRGame?, CKRError> = { .success(nil) }
    var deleteGame: @Sendable () async -> Result<Bool, CKRError> = { .success(true) }
}


extension CKRClient: DependencyKey {
    static let liveValue = Self(
        newGame: { newGame in
            do {
                let ckrGameRef = Firestore.firestore().collection("ckrGames").document(newGame.id.uuidString)
                try ckrGameRef.setData(from: newGame)
                return .success(true)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        getGame: {
            do {
                let querySnapshot = try await Firestore.firestore().collection("ckrGames").getDocuments()
                let documents = querySnapshot.documents
                
                guard let document = documents.first else {
                    return .success(nil)
                }
                
                let game = try document.data(as: CKRGame.self)
                return .success(game)
            } catch {
                return .failure(CKRError.fromFirestoreError(error))
            }
        },
        deleteGame: {
            do {
                    let db = Firestore.firestore()
                    let ckrGameRef = db.collection("ckrGames")
                    let snapshot = try await ckrGameRef.getDocuments()

                    guard !snapshot.documents.isEmpty else {
                        return .success(true)
                    }

                    let batch = db.batch()
                    for document in snapshot.documents {
                        batch.deleteDocument(document.reference)
                    }

                    try await batch.commit()
                    return .success(true)
                } catch {
                    return .failure(CKRError.fromFirestoreError(error))
                }
        }
    )

    static var previewValue: CKRClient {
        Self(
            newGame: { _ in .success(true) },
            getGame: { .success(nil) },
            deleteGame: { .success(true) }
        )
    }

    static var testValue: CKRClient {
        Self(
            newGame: { _ in .success(true) },
            getGame: { .success(nil) },
            deleteGame: { .success(true) }
        )
    }
}

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
