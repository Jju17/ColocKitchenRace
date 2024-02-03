//
//  HomeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {

    // MARK: - Reducer

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        var currentUser: User?
        var cohousing: Cohousing?
    }

    enum Action {
        case addCohousingButtonTapped
        case cancelCohousingButtonTapped
        case path(StackAction<Path.State, Path.Action>)
        case saveCohousingButtonTapped
    }

    @Reducer
    struct Path {
        @ObservableState
        enum State {
            case profile(UserProfileFeature.State)
        }
        enum Action {
            case profile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.profile, action: \.profile) {
                UserProfileFeature()
            }
        }
    }

    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addCohousingButtonTapped:
                return .none
            case .cancelCohousingButtonTapped:
                return .none
            case .path:
                return .none
            case .saveCohousingButtonTapped:
                return .none
            }
        }
        .forEach(\.path, action: \.path) { Path() }
    }
}

struct HomeView: View {
    @Perception.Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                VStack {
                    if let _ = store.cohousing {
                        //                    NavigationLink(
                        //                        state: AppFeature.Path.State.details(CohousingDetailFeature.State(cohousing: viewStore.cohousing!))
                        //                    ) {
                        //                        CohouseTileView(name: viewStore.cohousing?.name)
                        //                    }
                    } else {
                        Button {
                            store.send(.addCohousingButtonTapped)
                        } label: {
                            CohouseTileView(name: store.cohousing?.name)
                        }
                    }
                    CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 03, day: 23, hour: 18))
                }
                .navigationTitle("Welcome")
                .toolbar {
                    NavigationLink(
                        state: HomeFeature.Path.State.profile(UserProfileFeature.State(user: store.currentUser ?? .mockUser))
                    ) {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            } destination: { store in
                switch store.state {
                case .profile:
                    if let store = store.scope(state: \.profile, action: \.profile) {
                        UserProfileView(store: store)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }

}
