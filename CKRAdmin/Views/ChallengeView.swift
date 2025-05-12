//
//  ChallengeView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 5/11/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ChallengeFeature {

    @Reducer
    enum Destination {
        case addChallenge(NewChallengeFormFeature)
    }

    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
    }

    enum Action: BindableAction {
        case addChallengeButtonTapped
        case binding(BindingAction<State>)
        case confirmAddChallengeButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case onTask
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .addChallengeButtonTapped:
                    state.destination = .addChallenge(NewChallengeFormFeature.State())
                    return .none
                case .binding:
                    return .none
                case .confirmAddChallengeButtonTapped:
                    return .none
                case .destination:
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .onTask:
                    return .run { send in

                    }
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

struct ChallengeView: View {
    @Bindable var store: StoreOf<ChallengeFeature>

    var body: some View {
        NavigationStack {
            List {
                Text("Challenge 1")
            }
            .navigationTitle("Challenge")
            .toolbar {
                Button {
                    self.store.send(.addChallengeButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(
            item: $store.scope(state: \.destination?.addChallenge, action: \.destination.addChallenge)
        ) { addChallengeStore in
            NavigationStack {
                NewChallengeFormView(store: addChallengeStore)
                    .navigationTitle("New challenge")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                store.send(.confirmAddChallengeButtonTapped)
                            }
                        }
                    }
            }
        }
        .task {
            store.send(.onTask)
        }
    }
}

#Preview {
    NavigationStack {
        ChallengeView(
            store: Store(initialState: ChallengeFeature.State()) {
                ChallengeFeature()
            }
        )
    }

}
