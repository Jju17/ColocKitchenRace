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
        case loggedIn(RootFeature.State)
        case loggedOut(LoginFeature.State)
    }
    
    enum Action {
        case loggedIn(RootFeature.Action)
        case loggedOut(LoginFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loggedOut(.userResponse(user)):
                state = AppFeature.State.loggedIn(RootFeature.State())
                return .none
            case .loggedOut, .loggedIn:
                return .none
            }

        }
        Scope(state: /AppFeature.State.loggedIn, action: /AppFeature.Action.loggedIn) {
            RootFeature()
        }

        Scope(state: /AppFeature.State.loggedOut, action: /AppFeature.Action.loggedOut) {
            LoginFeature()
        }
    
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        switch store.state {
        case .loggedIn:
            if let rootStore = store.scope(state: \.loggedIn, action: \.loggedIn) {
                RootView(store: rootStore)
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
        store: Store(initialState: AppFeature.State.loggedIn(RootFeature.State())) {
            AppFeature()
        }
    )
}


