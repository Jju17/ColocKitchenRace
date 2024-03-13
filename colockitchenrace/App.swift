//
//  App.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    
    @ObservableState
    enum State {
        case root(RootFeature.State)
        case signin(SigninFeature.State)
        case signup(SignupFeature.State)
    }
    
    enum Action {
        case root(RootFeature.Action)
        case signin(SigninFeature.Action)
        case signup(SignupFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .signup(.changeToSigninButtonTapped):
                state = AppFeature.State.signin(SigninFeature.State())
                return .none
            case .signin(.changeToSignupButtonTapped):
                state = AppFeature.State.signup(SignupFeature.State())
                return .none
            case let .signin(.userResponse(_)):
                state = AppFeature.State.root(RootFeature.State())
                return .none
            case .signup(.signupButtonTapped):
                state = AppFeature.State.root(RootFeature.State())
                return .none
            case .signin, .signup, .root:
                return .none
            }

        }
        Scope(state: /AppFeature.State.root, action: /AppFeature.Action.root) {
            RootFeature()
        }
        Scope(state: /AppFeature.State.signin, action: /AppFeature.Action.signin) {
            SigninFeature()
        }
        Scope(state: /AppFeature.State.signup, action: /AppFeature.Action.signup) {
            SignupFeature()
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        switch store.state {
        case .root:
            if let rootStore = store.scope(state: \.root, action: \.root) {
                RootView(store: rootStore)
            }
        case .signin:
            if let signinStore = store.scope(state: \.signin, action: \.signin) {
                LoginView(store: signinStore)
            }
        case .signup:
            if let signupStore = store.scope(state: \.signup, action: \.signup) {
                SignupView(store: signupStore)
            }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State.root(RootFeature.State())) {
            AppFeature()
        }
    )
}


