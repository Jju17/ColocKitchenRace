//
//  ChallengeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ChallengeFeature {

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .path:
                return .none
            }
        }
    }
}

struct ChallengeView: View {
    @Perception.Bindable var store: StoreOf<ChallengeFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                ScrollView(.horizontal) {
                    HStack {
                        Color(.blue)
                            .frame(minWidth: 350, maxHeight: .infinity)
                        Color(.yellow)
                            .frame(minWidth: 350, maxHeight: .infinity)
                        Color(.red)
                            .frame(minWidth: 350, maxHeight: .infinity)

                    }
                    .padding()
                }
                .navigationTitle("Challenges")
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
    ChallengeView(store: .init(initialState: ChallengeFeature.State()) {
        ChallengeFeature()
    })
}
