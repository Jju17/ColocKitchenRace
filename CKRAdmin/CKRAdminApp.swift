//
//  CKRAdminApp.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 3/17/25.
//

import ComposableArchitecture
import Firebase
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct AdminCKRApp: App {

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
        }
    }
}
