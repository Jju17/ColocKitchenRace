//
//  RootView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 04/11/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

struct RootFeature: Reducer {
    struct State: Equatable {
        var currentUser: User?
        var userSession: FirebaseAuth.User?
    }
    enum Action: Equatable {
        case firstAction
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .firstAction:
                return .none
            }
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            if viewStore.userSession != nil {
                HomeView(store: Store(initialState: HomeFeature.State(), reducer: {
                    HomeFeature()
                }))
            } else {
                LoginView(store: Store(initialState: LoginFeature.State(), reducer: {
                    LoginFeature()
                }))
            }
        }
    }
}

#Preview {
    RootView(store: Store(initialState: RootFeature.State()) {
        RootFeature()
    })
}
