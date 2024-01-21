//
//  App.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

struct AppFeature: Reducer {
    struct State: Equatable {
        var home = HomeFeature.State()
        var path = StackState<Path.State>()
        var userSession: FirebaseAuth.User?
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
    }

    struct Path: Reducer {
        enum State: Equatable {
            case details(CohousingDetailFeature.State)
            case login(LoginFeature.State)
            case userProfile(UserProfileFeature.State)
        }
        enum Action: Equatable {
            case details(CohousingDetailFeature.Action)
            case login(LoginFeature.Action)
            case userProfile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: /State.details, action: /Action.details) {
                CohousingDetailFeature()
            }
            Scope(state: /State.login, action: /Action.login) {
                LoginFeature()
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
            case .path:
                return .none
            case .home:
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
            case .details:
                CaseLet(
                    /AppFeature.Path.State.details,
                     action: AppFeature.Path.Action.details,
                     then: CohousingDetailView.init(store:)
                )
            case .userProfile:
                CaseLet(
                    /AppFeature.Path.State.userProfile,
                     action: AppFeature.Path.Action.userProfile,
                     then: UserProfileView.init(store:)
                )
            case .login:
                CaseLet(
                    /AppFeature.Path.State.login,
                     action: AppFeature.Path.Action.login,
                     then: LoginView.init(store:)
                )
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
