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
    @CasePathable
    enum State: Equatable {
        case tab(TabFeature.State)
        case signin(SigninFeature.State)
        case signup(SignupFeature.State)
        case splashScreen(SplashScreenFeature.State)
    }

    @CasePathable
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
                    for await user in self.authentificationClient.listenAuthState() {
                        await send(.newAuthStateTrigger(user))
                    }
                }
            case let .newAuthStateTrigger(user):
                if user != nil {
                    state = State.tab(TabFeature.State())
                } else {
                    state = State.signin(SigninFeature.State())
                }
                return .none
            case let .signin(.delegate(action)):
                switch action {
                case .switchToSignupButtonTapped:
                    state = State.signup(SignupFeature.State())
                    return .none
                }
            case let .signup(.delegate(action)):
                switch action {
                case .switchToSigninButtonTapped:
                    state = State.signin(SigninFeature.State())
                    return .none
                }
            case .tab, .signin, .signup, .splashScreen:
                return .none
            }
        }
        .ifCaseLet(\.tab, action: \.tab) { TabFeature() }
        .ifCaseLet(\.signin, action: \.signin) { SigninFeature() }
        .ifCaseLet(\.signup, action: \.signup) { SignupFeature() }
        .ifCaseLet(\.splashScreen, action: \.splashScreen) { SplashScreenFeature() }
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
