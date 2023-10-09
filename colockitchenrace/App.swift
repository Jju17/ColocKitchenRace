//
//  App.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
    struct State {
        var home = HomeFeature.State()
        var path = StackState<Path.State>()
    }

    enum Action {
        case home(HomeFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
    }

    struct Path: Reducer {
        enum State {
            case detail(CohousingDetailFeature.State)
            case userProfile(UserProfileFeature.State)
        }
        enum Action {
            case detail(CohousingDetailFeature.Action)
            case userProfile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: /State.detail, action: /Action.detail) {
                CohousingDetailFeature()
            }
            Scope(state: /State.userProfile, action: /Action.userProfile) {
                UserProfileFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case .home:
                return .none
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStackStore(
            self.store.scope(state: \.path, action: { .path($0) })
        ) {
            HomeView(
                store: self.store.scope(
                    state: \.home,
                    action: { .home($0) }
                )
            )
        } destination: { state in
            switch state {
            case .detail:
                CaseLet(
                    /AppFeature.Path.State.detail,
                     action: AppFeature.Path.Action.detail
                ) { CohousingDetailView(store: $0) }
            case .userProfile:
                CaseLet(
                    /AppFeature.Path.State.userProfile,
                     action: AppFeature.Path.Action.userProfile
                ) { UserProfileView(store: $0) }
            }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
