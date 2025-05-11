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
