//
//  colockitchenraceApp.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import Firebase
import SwiftUI
import MijickPopups

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

    @Dependency(\.ckrClient) var ckrClient
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
            let _ = try? await self.newsClient.getLast()
        }
    }
}
