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

    init() {
        FirebaseApp.configure()
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
}
