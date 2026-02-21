//
//  ContentView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 02/11/2024.
//

import ComposableArchitecture
import FirebaseAuth
import os
import SwiftUI

@Reducer
struct AppFeature {

    @ObservableState
    enum State {
        case tab(TabFeature.State)
        case signin(SigninFeature.State)
        case splashScreen(SplashScreenFeature.State)
    }

    enum Action {
        case onTask
        case tab(TabFeature.Action)
        case signin(SigninFeature.Action)
        case splashScreen(SplashScreenFeature.Action)
        case newAuthStateTrigger(FirebaseAuth.User?)
        case adminCheckCompleted(isAdmin: Bool)
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    for await user in self.authenticationClient.listenAuthState() {
                        await send(.newAuthStateTrigger(user))
                    }
                }
            case let .newAuthStateTrigger(user):
                if let user {
                    state = .splashScreen(SplashScreenFeature.State())
                    return .run { send in
                        do {
                            let isAdmin = try await self.authenticationClient.verifyAdmin(user.uid)
                            await send(.adminCheckCompleted(isAdmin: isAdmin))
                        } catch {
                            Logger.authLog.log(level: .error, "Admin verification failed: \(error)")
                            await send(.adminCheckCompleted(isAdmin: false))
                        }
                    }
                } else {
                    // Don't overwrite signin screen that already shows an error (after non-admin rejection)
                    if case let .signin(signinState) = state, signinState.error != nil {
                        return .none
                    }
                    state = .signin(SigninFeature.State())
                    return .none
                }
            case let .adminCheckCompleted(isAdmin):
                if isAdmin {
                    state = .tab(TabFeature.State())
                } else {
                    state = .signin(SigninFeature.State(error: AuthError.notAdmin))
                    return .run { _ in
                        try? await self.authenticationClient.signOut()
                    }
                }
                return .none
            case .tab, .signin, .splashScreen:
                return .none
            }
        }
        .ifCaseLet(\.tab, action: \.tab) {
            TabFeature()
        }
        .ifCaseLet(\.signin, action: \.signin) {
            SigninFeature()
        }
        .ifCaseLet(\.splashScreen, action: \.splashScreen) {
            SplashScreenFeature()
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.state {
            case .tab:
                if let rootStore = store.scope(state: \.tab, action: \.tab) {
                    MyTabView(store: rootStore)
                }
            case .signin:
                if let signinStore = store.scope(state: \.signin, action: \.signin) {
                    SigninView(store: signinStore)
                }
            case .splashScreen:
                if let splashScreenStore = store.scope(state: \.splashScreen, action: \.splashScreen) {
                    SplashScreenView(store: splashScreenStore)
                }
            }
        }
        .task {
            self.store.send(.onTask)
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State.tab(TabFeature.State())) {
            AppFeature()
        }
    )
}
