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
import FirebaseFunctions
import os

enum CohouseError: Error, Equatable {
    case networkError
    case permissionDenied
    case unknown(String)
}

/// Lightweight cohouse data for map display (CKRAdmin only).
struct CohouseMapItem: Equatable, Identifiable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var userNames: [String]
}

@DependencyClient
struct CohouseClient {
    var totalCohousesCount: @Sendable () async -> Result<Int, CohouseError> = { .success(0) }
    var getCohouses: @Sendable (_ ids: [String]) async -> Result<[CohouseMapItem], CohouseError> = { _ in .success([]) }
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
        },
        getCohouses: { ids in
            do {
                let functions = Functions.functions(region: "europe-west1")
                let callable = functions.httpsCallable("getCohousesForMap")
                let result = try await callable.call(["cohouseIds": ids])

                guard let dict = result.data as? [String: Any],
                      let cohousesArray = dict["cohouses"] as? [[String: Any]]
                else {
                    return .failure(.unknown("Invalid response format"))
                }

                let items = cohousesArray.compactMap { data -> CohouseMapItem? in
                    guard let id = data["id"] as? String,
                          let name = data["name"] as? String,
                          let latitude = data["latitude"] as? Double,
                          let longitude = data["longitude"] as? Double
                    else { return nil }

                    let userNames = data["userNames"] as? [String] ?? []

                    return CohouseMapItem(
                        id: id,
                        name: name,
                        latitude: latitude,
                        longitude: longitude,
                        userNames: userNames
                    )
                }

                return .success(items)
            } catch {
                Logger.cohouseLog.log(level: .fault, "getCohouses: \(error.localizedDescription)")
                return .failure(.unknown(error.localizedDescription))
            }
        }
    )

    static var previewValue: CohouseClient {
        Self(
            totalCohousesCount: { .success(42) },
            getCohouses: { ids in
                .success(ids.enumerated().map { index, id in
                    CohouseMapItem(
                        id: id,
                        name: "Coloc \(index + 1)",
                        latitude: 50.845 + Double(index) * 0.003,
                        longitude: 4.345 + Double(index) * 0.003,
                        userNames: ["Alice", "Bob"]
                    )
                })
            }
        )
    }

    static var testValue: CohouseClient {
        Self(
            totalCohousesCount: { .success(0) },
            getCohouses: { _ in .success([]) }
        )
    }
}

extension DependencyValues {
    var cohouseClient: CohouseClient {
        get { self[CohouseClient.self] }
        set { self[CohouseClient.self] = newValue }
    }
}
