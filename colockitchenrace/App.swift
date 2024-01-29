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
        case loggedIn(HomeFeature.State)
        case loggedOut(LoginFeature.State)
    }

    enum Action {
        case loggedIn(HomeFeature.Action)
        case loggedOut(LoginFeature.Action)
        case logIn
    }

    var body: some ReducerOf<Self> {
        Scope(state: /AppFeature.State.loggedIn, action: /AppFeature.Action.loggedIn) {
            HomeFeature()
        }

        Scope(state: /AppFeature.State.loggedOut, action: /AppFeature.Action.loggedOut) {
            LoginFeature()
        }

        Reduce { state, action in
            switch action {
            case .logIn:
                state = .loggedIn(HomeFeature.State())
                return .none
            case .loggedIn:
                return .none
            case .loggedOut:
                return .none
            }
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    var body: some View {
        switch store.state {
        case .loggedIn:
            if let homeStore = store.scope(state: \.loggedIn, action: \.loggedIn) {
                HomeView(store: homeStore)
            }
        case .loggedOut:
            if let signInStore = store.scope(state: \.loggedOut, action: \.loggedOut) {
                LoginView(store: signInStore)
            }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State.loggedOut(LoginFeature.State())) {
            AppFeature()
        }
    )
}
