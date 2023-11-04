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
            case details(CohousingDetailFeature.State)
            case login(LoginFeature.State)
            case userProfile(UserProfileFeature.State)
        }
        enum Action {
            case details(CohousingDetailFeature.Action)
            case login(LoginFeature.Action)
            case userProfile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: /State.details, action: /Action.details) {
                CohousingDetailFeature()
            }
            Scope(state: /State.userProfile, action: /Action.userProfile) {
                UserProfileFeature()
            }
            Scope(state: /State.login, action: /Action.login) {
                LoginFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: /Action.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .path(.element(id: _, action: .details(.delegate(action)))):
                switch action {
                case let .cohousingUpdated(cohousing):
                    state.home.cohousing = cohousing
                    return .none
                }
            case let .path(.element(id: _, action: .login(.delegate(action)))):
                switch action {
                case let .userUpdated(user):
                    state.home.currentUser = user
                    return .none
                }
            case .home(.onAppear):
                state.path.append(.login(LoginFeature.State()))
                return .none
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
