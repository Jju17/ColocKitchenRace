//
//  colocskitchenraceApp.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import Firebase
import FirebaseMessaging
import GoogleSignIn
import os
import StripePaymentSheet
import SwiftUI
import MijickPopups
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.ckrClient) var ckrClient
    @Dependency(\.newsClient) var newsClient

    private var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard !isTesting else { return true }

        FirebaseApp.configure()

        // Start real-time Firestore listeners (must be after FirebaseApp.configure)
        let ckr = ckrClient
        let news = newsClient
        Task {
            for await _ in ckr.listenToGame() {}
        }
        Task {
            for await _ in news.listenToNews() {}
        }

        // Configure Google Sign-In
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        StripeAPI.defaultPublishableKey = Bundle.main.infoDictionary?["StripePublishableKey"] as? String ?? ""

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
            Logger.globalLog.info("Notification permission granted: \(granted)")
            if granted {
                await MainActor.run {
                    application.registerForRemoteNotifications()
                }
            }
        } catch {
            Logger.globalLog.error("Error requesting notification permission: \(error)")
        }
    }

    // MARK: - URL Handling (Google Sign-In)

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.globalLog.error("Failed to register for remote notifications: \(error)")
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        Logger.globalLog.info("FCM Token received")

        // Store FCM token and subscribe to topic
        Task {
            do {
                try await notificationClient.storeFCMToken(fcmToken)
            } catch {
                Logger.globalLog.error("Failed to store FCM token: \(error)")
            }

            do {
                try await Messaging.messaging().subscribe(toTopic: "all_users")
            } catch {
                Logger.globalLog.error("Failed to subscribe to all_users topic: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    // Handle notification tap — extract deep link type from payload and post to NotificationCenter
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        Logger.globalLog.info("Notification tapped with data: \(userInfo)")

        guard let type = userInfo["type"] as? String else { return }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .ckrDeepLink,
                object: nil,
                userInfo: ["type": type, "data": userInfo]
            )
        }
    }
}

@main
struct colocskitchenraceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

}
