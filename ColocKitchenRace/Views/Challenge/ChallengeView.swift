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
        var challenges: [Challenge]
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
    }

    @Reducer
    struct Path {
        @ObservableState
        enum State {
            case profile(UserProfileDetailFeature.State)
        }
        enum Action {
            case profile(UserProfileDetailFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.profile, action: \.profile) {
                UserProfileDetailFeature()
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
                VStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(self.store.challenges) { challenge in
                                ChallengeTileView(challenge: challenge)
                            }
                        }
                    }
                    .onAppear {
                        UIScrollView.appearance().isPagingEnabled = true
                    }
                    .navigationTitle("Challenges")
                }
            } destination: { store in
                switch store.state {
                case .profile:
                    if let store = store.scope(state: \.profile, action: \.profile) {
                        UserProfileDetailView(store: store)
                    }
                }
            }
        }
    }
}

#Preview {
    ChallengeView(store: .init(initialState: ChallengeFeature.State(challenges: Challenge.mockList)) {
        ChallengeFeature()
    })
}
