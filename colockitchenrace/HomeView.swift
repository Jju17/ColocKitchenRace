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

    @Reducer
    enum Path {
        case profile(UserProfileDetailFeature)
    }

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        var currentUser: User?
        var cohousing: Cohouse?
    }

    enum Action {
        case addCohousingButtonTapped
        case cancelCohousingButtonTapped
        case logoutButtonTapped
        case path(StackActionOf<Path>)
        case saveCohousingButtonTapped
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addCohousingButtonTapped:
                return .none
            case .cancelCohousingButtonTapped:
                return .none
            case .logoutButtonTapped:
                self.authentificationClient.signOut()
                return .none
            case .path:
                return .none
            case .saveCohousingButtonTapped:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

struct HomeView: View {
    @Perception.Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                ScrollView {
                    VStack(spacing: 15) {
                        CohouseTileView(name: store.cohousing?.name)
                        CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 09, day: 06, hour: 18))
                    }
                }
                .padding()
                .navigationTitle("Welcome")
                .toolbar {
                    NavigationLink(
                        state: HomeFeature.Path.State.profile(UserProfileDetailFeature.State())
                    ) {
                        Image(systemName: "person.crop.circle.fill")
                    }
                    Button {
                        self.store.send(.logoutButtonTapped)
                    } label: {
                        Image(systemName: "nosign.app.fill")
                    }

                }
            } destination: { store in
                switch store.case {
                case let .profile(store):
                    UserProfileDetailView(store: store)
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
