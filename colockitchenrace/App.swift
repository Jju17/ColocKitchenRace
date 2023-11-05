//
//  App.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
    struct State: Equatable {
        var root = RootFeature.State()
        var path = StackState<Path.State>()
    }

    enum Action: Equatable {
        case root(RootFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
    }

    struct Path: Reducer {
        enum State: Equatable {
            case details(CohousingDetailFeature.State)
            case userProfile(UserProfileFeature.State)
        }
        enum Action: Equatable {
            case details(CohousingDetailFeature.Action)
            case userProfile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: /State.details, action: /Action.details) {
                CohousingDetailFeature()
            }
            Scope(state: /State.userProfile, action: /Action.userProfile) {
                UserProfileFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
//            case let .path(.element(id: _, action: .details(.delegate(action)))):
//                switch action {
//                case let .cohousingUpdated(cohousing):
//                    state.home.cohousing = cohousing
//                    return .none
//                }
//                return .none
//            case .home(.onAppear):
//                print("JR: Home is appeared")
////                state.path.append(.login(LoginFeature.State()))
//                return .none
//            case .home:
//                return .none
            case .path:
                return .none
            case .root:
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
//            HomeView(
//                store: self.store.scope(
//                    state: \.home,
//                    action: { .home($0) }
//                )
//            )
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                RootView(
                    store: self.store.scope(
                        state: \.root,
                        action: { .root($0) }
                    )
                )
            }
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
