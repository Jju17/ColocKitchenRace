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
        var challengeTiles: IdentifiedArrayOf<ChallengeTileFeature.State> = []
        var isLoading: Bool = false
        var errorMessage: String?
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case fetchChallenges
        case challengeTiles(IdentifiedActionOf<ChallengeTileFeature>)
        case challengesLoaded(Result<[Challenge], ChallengesClientError>)
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

    @Dependency(\.challengesClient) var challengesClient
    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .path:
                return .none
            case .fetchChallenges:
                state.isLoading = true
                return .run { send in
                    let result = try await self.challengesClient.getAll()
                    await send(.challengesLoaded(result))
                }
                case .challengesLoaded(.success(let challenges)):
                    state.challengeTiles = IdentifiedArray(
                        uniqueElements: challenges.map {
                            ChallengeTileFeature.State(id: $0.id, challenge: $0, response: nil)
                        }
                    )
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case .challengesLoaded(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                case .challengeTiles:
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
                    if store.isLoading {
                        ProgressView("Loading challenges...")
                    } else if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
//                                ForEach(
//                                  store.scope(state: \.challengeTiles, action: \.challengeTiles),
//                                  content: ChallengeTileView()
//                                )
                            }
                        }
                        .introspect(.scrollView, on: .iOS(.v16), .iOS(.v17), .iOS(.v18)) {
                            $0.isPagingEnabled = true
                        }
                    }
                }
                .navigationTitle("Challenges")
            } destination: { store in
                switch store.state {
                case .profile:
                    if let store = store.scope(state: \.profile, action: \.profile) {
                        UserProfileDetailView(store: store)
                    }
                }
            }
            .onAppear {
                store.send(.fetchChallenges)
            }
        }
    }
}

#Preview {
    ChallengeView(
        store: Store(initialState: ChallengeFeature.State(/*challengeTiles: IdentifiedArray(uniqueElements: Challenge.mockList)*/)) {
            ChallengeFeature()
        }
    )
}
