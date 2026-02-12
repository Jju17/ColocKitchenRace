//
//  UserClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseFunctions
import os

enum UserError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)

    static func fromError(_ error: Error) -> UserError {
        let nsError = error as NSError
        switch nsError.code {
        case FirestoreErrorCode.unavailable.rawValue:
            return .networkError
        case FirestoreErrorCode.permissionDenied.rawValue:
            return .permissionDenied
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

@DependencyClient
struct UserClient {
    var totalUsersCount: @Sendable () async -> Result<Int, UserError> = { .success(0) }
    var searchUsers: @Sendable (_ query: String) async -> Result<[User], UserError> = { _ in .success([]) }
    var setAdminClaim: @Sendable (_ authUid: String, _ isAdmin: Bool) async -> Result<Void, UserError> = { _, _ in .success(()) }
    var updateUserAdminStatus: @Sendable (_ userId: String, _ isAdmin: Bool) async -> Result<Void, UserError> = { _, _ in .success(()) }
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
        },
        searchUsers: { query in
            do {
                let queryLowercased = query.lowercased()
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .getDocuments()

                let allUsers = snapshot.documents.compactMap { doc -> User? in
                    try? doc.data(as: User.self)
                }

                let filtered = allUsers.filter { user in
                    user.firstName.lowercased().contains(queryLowercased)
                    || user.lastName.lowercased().contains(queryLowercased)
                    || (user.email?.lowercased().contains(queryLowercased) ?? false)
                }

                let sorted = filtered.sorted { $0.firstName.lowercased() < $1.firstName.lowercased() }
                return .success(sorted)
            } catch {
                Logger.authLog.log(level: .fault, "searchUsers error: \(error.localizedDescription)")
                return .failure(.fromError(error))
            }
        },
        setAdminClaim: { authUid, isAdmin in
            do {
                let functions = Functions.functions(region: "europe-west1")
                _ = try await functions.httpsCallable("setAdminClaim").call([
                    "targetAuthUid": authUid,
                    "isAdmin": isAdmin,
                ])
                return .success(())
            } catch {
                Logger.authLog.log(level: .fault, "setAdminClaim error: \(error.localizedDescription)")
                return .failure(.fromError(error))
            }
        },
        updateUserAdminStatus: { userId, isAdmin in
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData(["isAdmin": isAdmin])
                return .success(())
            } catch {
                Logger.authLog.log(level: .fault, "updateUserAdminStatus error: \(error.localizedDescription)")
                return .failure(.fromError(error))
            }
        }
    )

    static var previewValue: UserClient {
        Self(
            totalUsersCount: { .success(42) },
            searchUsers: { _ in .success(User.mockUsers) },
            setAdminClaim: { _, _ in .success(()) },
            updateUserAdminStatus: { _, _ in .success(()) }
        )
    }

    static var testValue: UserClient {
        Self(
            totalUsersCount: { .success(0) },
            searchUsers: { _ in .success([]) },
            setAdminClaim: { _, _ in .success(()) },
            updateUserAdminStatus: { _, _ in .success(()) }
        )
    }
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
