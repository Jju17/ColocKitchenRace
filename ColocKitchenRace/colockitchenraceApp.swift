//
//  colockitchenraceApp.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import Firebase
import FirebaseMessaging
import SwiftUI
import MijickPopups
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    @Dependency(\.notificationClient) var notificationClient

    private var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard !isTesting else { return true }

        FirebaseApp.configure()

        // Configure notification center
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request notification permission
        Task {
            await requestNotificationPermission(application)
        }

        return true
    }

    private func requestNotificationPermission(_ application: UIApplication) async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 Notification permission granted: \(granted)")
            if granted {
                await MainActor.run {
                    application.registerForRemoteNotifications()
                }
            }
        } catch {
            print("🔔 Error requesting notification permission: \(error)")
        }
    }

    // MARK: - APNs Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 Failed to register for remote notifications: \(error)")
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("🔔 FCM Token: \(fcmToken)")

        // Store FCM token and subscribe to topic
        Task {
            try? await notificationClient.storeFCMToken(fcmToken)

            // Always subscribe to all_users topic when we have a token
            try? await Messaging.messaging().subscribe(toTopic: "all_users")
            print("🔔 Subscribed to 'all_users' topic")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 Notification tapped with data: \(userInfo)")
        // TODO: Handle deep linking based on notification data
    }
}

@main
struct colockitchenraceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Dependency(\.ckrClient) var ckrClient
    @Dependency(\.newsClient) var newsClient

    private var newsListenerTask: Task<Void, Never>?

    private var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        guard !isTesting else { return }
        self.performFetchs()
        self.startNewsListener()
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(
                    initialState: AppFeature.State.splashScreen(SplashScreenFeature.State())
                ) {
                    AppFeature()
                }
            )
            .preferredColorScheme(.light)
            .registerPopups(id: .shared) { config in config
                    .vertical { $0
                        .enableDragGesture(true)
                        .tapOutsideToDismissPopup(true)
                        .cornerRadius(32)
                    }
                    .center { $0
                        .tapOutsideToDismissPopup(true)
                        .backgroundColor(.white)
                    }
            }
        }
    }

    private func performFetchs() {
        Task {
            let _ = try? await self.ckrClient.getLast()
        }
    }

    private func startNewsListener() {
        Task {
            for await _ in newsClient.listenToNews() {
                // News are automatically updated in shared state by the listener
            }
        }
    }
}
