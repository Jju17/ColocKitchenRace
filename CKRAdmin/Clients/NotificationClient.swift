//
//  NotificationClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore
import FirebaseFunctions

@DependencyClient
struct NotificationClient: Sendable {
    var sendToAll: @Sendable (_ title: String, _ body: String) async throws -> NotificationResult
    var sendToCohouse: @Sendable (_ cohouseId: String, _ title: String, _ body: String) async throws -> NotificationResult
    var sendToEdition: @Sendable (_ editionId: String, _ title: String, _ body: String) async throws -> NotificationResult
    var getHistory: @Sendable () async throws -> [NotificationHistoryItem]
}

struct NotificationResult: Equatable {
    var success: Bool
    var sent: Int?
    var failed: Int?
    var messageId: String?
    var message: String?
}

struct NotificationHistoryItem: Equatable, Identifiable {
    var id: String
    var target: String
    var targetId: String?
    var title: String
    var body: String
    var sent: Int
    var failed: Int
    var message: String?
    var sentAt: Date?
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
                failed: data["failed"] as? Int,
                message: data["message"] as? String
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
                failed: data["failed"] as? Int,
                message: data["message"] as? String
            )
        },
        getHistory: {
            let db = Firestore.firestore()
            let snapshot = try await db
                .collection("notificationHistory")
                .order(by: "sentAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            return snapshot.documents.compactMap { doc -> NotificationHistoryItem? in
                let data = doc.data()
                guard let target = data["target"] as? String,
                      let title = data["title"] as? String,
                      let body = data["body"] as? String
                else { return nil }

                let sentAt = (data["sentAt"] as? Timestamp)?.dateValue()

                return NotificationHistoryItem(
                    id: doc.documentID,
                    target: target,
                    targetId: data["targetId"] as? String,
                    title: title,
                    body: body,
                    sent: data["sent"] as? Int ?? 0,
                    failed: data["failed"] as? Int ?? 0,
                    message: data["message"] as? String,
                    sentAt: sentAt
                )
            }
        }
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
