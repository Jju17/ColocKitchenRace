//
//  App.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

@Reducer
struct AppFeature {

    @ObservableState
    enum State {
        case tab(TabFeature.State)
        case signin(SigninFeature.State)
        case signup(SignupFeature.State)
        case splashScreen(SplashScreenFeature.State)
    }

    enum Action {
        case onTask
        case tab(TabFeature.Action)
        case signin(SigninFeature.Action)
        case signup(SignupFeature.Action)
        case splashScreen(SplashScreenFeature.Action)
        case newAuthStateTrigger(FirebaseAuth.User?)
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    for await user in try authentificationClient.listenAuthState() {
                        await send(.newAuthStateTrigger(user))
                    }
                }
            case let .newAuthStateTrigger(user):
                if user != nil {
                    state = AppFeature.State.tab(TabFeature.State())
                } else {
                    state = AppFeature.State.signin(SigninFeature.State())
                }
                return .none
            case let .signup(.delegate(action)):
                switch action {
                case .switchToSigninButtonTapped:
                    state = AppFeature.State.signin(SigninFeature.State())
                    return .none
                }
            case .tab, .signin, .signup, .splashScreen:
                return .none
            }

        }
        .ifCaseLet(/State.tab, action: /Action.tab) {
            TabFeature()
        }
        .ifCaseLet(/State.signin, action: /Action.signin) {
            SigninFeature()
        }
        .ifCaseLet(/State.signup, action: /Action.signup) {
            SignupFeature()
        }
        .ifCaseLet(/State.splashScreen, action: /Action.splashScreen) {
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
            case .signup:
                if let signupStore = store.scope(state: \.signup, action: \.signup) {
                    SignupView(store: signupStore)
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


