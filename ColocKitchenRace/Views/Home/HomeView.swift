//
//  HomeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
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
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        @Shared(.news) var news
        @Shared(.userInfo) var userInfo
    }

    enum Action {
        case openRegisterLink
        case path(StackActionOf<Path>)
        case switchToCohouseButtonTapped
    }

    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .openRegisterLink:
                guard let cohouse = state.cohouse
                else { return .none}
                let _ = self.ckrClient.registerCohouse(cohouse: cohouse)
                return .none
            case .path:
                return .none
            case .switchToCohouseButtonTapped:
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
                        Button {
                            store.send(.switchToCohouseButtonTapped)
                        } label: {
                            CohouseTileView(name: store.cohouse?.name)
                        }

                        Button {
                            self.store.send(.openRegisterLink)
                        } label: {
                            CountdownTileView(nextKitchenRace: self.store.ckrGame?.nextGameDate)
                        }
                        NewsTileView(allNews: self.store.$news)
                    }
                }
                .padding(.horizontal)
                .navigationTitle("Colocs Kitchen Race")
                .toolbar {
                    NavigationLink(
                        state: HomeFeature.Path.State.profile(UserProfileDetailFeature.State())
                    ) {
                        Image(systemName: "person.crop.circle.fill")
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
