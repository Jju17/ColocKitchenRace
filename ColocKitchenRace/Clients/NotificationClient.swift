//
//  NotificationClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import FirebaseFirestore
import FirebaseMessaging
import os

// MARK: - Client Interface

@DependencyClient
struct NotificationClient: Sendable {
    var storeFCMToken: @Sendable (_ token: String) async throws -> Void
    var subscribeToAllUsers: @Sendable () async throws -> Void
    var unsubscribeFromAllUsers: @Sendable () async throws -> Void
}

// MARK: - Implementations

extension NotificationClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        storeFCMToken: { token in
            @Shared(.userInfo) var userInfo

            guard let user = userInfo else {
                Logger.globalLog.log(level: .info, "No user logged in, cannot store FCM token")
                return
            }

            $userInfo.withLock { $0?.fcmToken = token }

            try await Firestore.firestore()
                .collection("users")
                .document(user.id.uuidString)
                .updateData(["fcmToken": token])

            Logger.globalLog.log(level: .info, "FCM token stored for user \(user.id)")
        },
        subscribeToAllUsers: {
            try await Messaging.messaging().subscribe(toTopic: "all_users")
            Logger.globalLog.log(level: .info, "Subscribed to 'all_users' topic")
        },
        unsubscribeFromAllUsers: {
            try await Messaging.messaging().unsubscribe(fromTopic: "all_users")
            Logger.globalLog.log(level: .info, "Unsubscribed from 'all_users' topic")
        }
    )

    // MARK: Test

    static let testValue = Self(
        storeFCMToken: { _ in },
        subscribeToAllUsers: {},
        unsubscribeFromAllUsers: {}
    )

    // MARK: Preview

    static let previewValue: NotificationClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
