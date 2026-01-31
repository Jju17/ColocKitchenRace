//
//  NotificationClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import Dependencies
import FirebaseFunctions

@DependencyClient
struct NotificationClient: Sendable {
    var sendToAll: @Sendable (_ title: String, _ body: String) async throws -> NotificationResult
    var sendToCohouse: @Sendable (_ cohouseId: String, _ title: String, _ body: String) async throws -> NotificationResult
    var sendToEdition: @Sendable (_ editionId: String, _ title: String, _ body: String) async throws -> NotificationResult
}

struct NotificationResult: Equatable {
    var success: Bool
    var sent: Int?
    var failed: Int?
    var messageId: String?
    var message: String?
}

extension NotificationClient: DependencyKey {
    static let liveValue = Self(
        sendToAll: { title, body in
            let functions = Functions.functions(region: "europe-west1")
            let result = try await functions.httpsCallable("sendNotificationToAll").call([
                "notification": [
                    "title": title,
                    "body": body
                ]
            ])

            guard let data = result.data as? [String: Any] else {
                return NotificationResult(success: false, message: "Invalid response")
            }

            return NotificationResult(
                success: data["success"] as? Bool ?? false,
                messageId: data["messageId"] as? String
            )
        },
        sendToCohouse: { cohouseId, title, body in
            let functions = Functions.functions(region: "europe-west1")
            let result = try await functions.httpsCallable("sendNotificationToCohouse").call([
                "cohouseId": cohouseId,
                "notification": [
                    "title": title,
                    "body": body
                ]
            ])

            guard let data = result.data as? [String: Any] else {
                return NotificationResult(success: false, message: "Invalid response")
            }

            return NotificationResult(
                success: data["success"] as? Bool ?? false,
                sent: data["sent"] as? Int,
                failed: data["failed"] as? Int
            )
        },
        sendToEdition: { editionId, title, body in
            let functions = Functions.functions(region: "europe-west1")
            let result = try await functions.httpsCallable("sendNotificationToEdition").call([
                "editionId": editionId,
                "notification": [
                    "title": title,
                    "body": body
                ]
            ])

            guard let data = result.data as? [String: Any] else {
                return NotificationResult(success: false, message: "Invalid response")
            }

            return NotificationResult(
                success: data["success"] as? Bool ?? false,
                sent: data["sent"] as? Int,
                failed: data["failed"] as? Int
            )
        }
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
