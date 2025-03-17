//
//  CKRAdminApp.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import Firebase
import SwiftUI

@main
struct AdminCKRApp: App {
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
