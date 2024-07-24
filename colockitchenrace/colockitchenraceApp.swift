//
//  colockitchenraceApp.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import Firebase
import SwiftUI

@main
struct colockitchenraceApp: App {

    @Dependency(\.globalInfoClient) var globalInfoClient
    @Dependency(\.newsClient) var newsClient

    init() {
        FirebaseApp.configure()
        self.performTasks()
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(
                    initialState: AppFeature.State.splashScreen(SplashScreenFeature.State())
                ) {
                    AppFeature()
                        ._printChanges()
                }
            )
            .preferredColorScheme(.light)
        }
    }

    private func performTasks() {
        Task {
            let _ = try? await self.globalInfoClient.getLast()
        }
        Task {
            let _ = try? await self.newsClient.getLast()
        }
    }
}
