//
//  HomeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct HomeFeature: Reducer {

    // MARK: - Reducer

    struct State: Equatable {
        @PresentationState var destination: Destination.State?
        @BindingState var currentUser: User?
        @BindingState var cohousing: Cohousing?
    }

    enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)
        case addCohousingButtonTapped
        case cancelCohousingButtonTapped
        case onAppear
        case saveCohousingButtonTapped
        case signInButtonTapped
        case userProfileButtonTapped
    }

    struct Destination: Reducer {
        enum State: Equatable {
            case addCohousing(CohousingFormFeature.State)
        }

        enum Action: Equatable {
            case addCohousing(CohousingFormFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(
                state: /State.addCohousing,
                action: /Action.addCohousing) {
                    CohousingFormFeature()
                }
        }
    }

    @Dependency(\.uuid) var uuid
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.addCohousing)):
                return .none
            case .destination(.dismiss):
                return .none
            case .addCohousingButtonTapped:
                state.destination = .addCohousing(CohousingFormFeature.State(cohousing: Cohousing(id: self.uuid())))
                return .none
            case .cancelCohousingButtonTapped:
                state.destination = nil
                return .none
            case .onAppear:
                return .none
            case .saveCohousingButtonTapped:
                guard case let .addCohousing(cohousing) = state.destination
                else { return .none }
                state.cohousing = cohousing.cohousing
                state.destination = nil
                return .none
            case .signInButtonTapped:
                return .none
            case .userProfileButtonTapped:
                return .none

            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}

struct HomeView: View {

    // MARK: - Store

    let store: StoreOf<HomeFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                if let _ = viewStore.cohousing {
                    NavigationLink(
                        state: AppFeature.Path.State.details(CohousingDetailFeature.State(cohousing: viewStore.cohousing!))
                    ) {
                        CohouseTileView(name: viewStore.cohousing?.name)
                    }
                } else {
                    Button {
                        viewStore.send(.addCohousingButtonTapped)
                    } label: {
                        CohouseTileView(name: viewStore.cohousing?.name)
                    }
                }
                CountdownTileView(nextKitchenRace: Date.from(year: 2024, month: 03, day: 23, hour: 18))
            }
            .navigationTitle("Welcome")
            .toolbar {
                NavigationLink(
                    state: AppFeature.Path.State.userProfile(UserProfileFeature.State(user: viewStore.currentUser ?? .mockUser2))
                ) {
                    Image(systemName: "person.crop.circle.fill")
                }
            }
            .sheet(
                store: self.store.scope(state: \.$destination, action: { .destination($0) } ),
                state: /HomeFeature.Destination.State.addCohousing,
                action: HomeFeature.Destination.Action.addCohousing
            ) { store in
                NavigationStack {
                    CohousingFormView(store: store)
                        .navigationTitle("New cohouse")
                        .toolbar {
                            ToolbarItem {
                                Button("Add") {
                                    viewStore.send(.saveCohousingButtonTapped)
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    viewStore.send(.cancelCohousingButtonTapped)
                                }
                            }
                        }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
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
