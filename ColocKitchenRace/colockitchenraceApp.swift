//
//  colockitchenraceApp.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import Firebase
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct colockitchenraceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Dependency(\.globalInfoClient) var globalInfoClient
    @Dependency(\.newsClient) var newsClient

    init() {
        self.performFetchs()
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
        }
    }

    private func performFetchs() {
        Task {
            let _ = try? await self.globalInfoClient.getLast()
            let _ = try? await self.newsClient.getLast()
        }
    }
}
