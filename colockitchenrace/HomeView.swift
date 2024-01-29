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
    struct State: Equatable {
        var currentUser: User?
        var cohousing: Cohousing?
    }

    enum Action: Equatable {
        case addCohousingButtonTapped
        case cancelCohousingButtonTapped
        case onAppear
        case saveCohousingButtonTapped
        case userProfileButtonTapped
    }

    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addCohousingButtonTapped:
                return .none
            case .cancelCohousingButtonTapped:
                return .none
            case .onAppear:
                return .none
            case .saveCohousingButtonTapped:
                return .none
            case .userProfileButtonTapped:
                return .none

            }
        }
    }
}

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
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
                    Image(systemName: "person.crop.circle.fill")
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
