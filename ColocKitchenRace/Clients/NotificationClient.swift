//
//  NotificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore
import FirebaseMessaging
import Sharing

@DependencyClient
struct NotificationClient: Sendable {
    var storeFCMToken: @Sendable (_ token: String) async throws -> Void
    var subscribeToAllUsers: @Sendable () async throws -> Void
    var unsubscribeFromAllUsers: @Sendable () async throws -> Void
}

extension NotificationClient: DependencyKey {
    static let testValue = Self(
        storeFCMToken: { _ in },
        subscribeToAllUsers: {},
        unsubscribeFromAllUsers: {}
    )

    static var previewValue: NotificationClient {
        return .testValue
    }

    static let liveValue = Self(
        storeFCMToken: { token in
            @Shared(.userInfo) var userInfo

            guard let user = userInfo else {
                print("🔔 No user logged in, cannot store FCM token")
                return
            }

            // Update local user with FCM token
            $userInfo.withLock { $0?.fcmToken = token }

            // Update Firestore
            try await Firestore.firestore()
                .collection("users")
                .document(user.id.uuidString)
                .updateData(["fcmToken": token])

            print("🔔 FCM token stored successfully for user \(user.id)")
        },
        subscribeToAllUsers: {
            try await Messaging.messaging().subscribe(toTopic: "all_users")
            print("🔔 Subscribed to 'all_users' topic")
        },
        unsubscribeFromAllUsers: {
            try await Messaging.messaging().unsubscribe(fromTopic: "all_users")
            print("🔔 Unsubscribed from 'all_users' topic")
        }
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
