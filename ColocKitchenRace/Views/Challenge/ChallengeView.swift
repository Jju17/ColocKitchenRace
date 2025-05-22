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
        var challenges: IdentifiedArrayOf<Challenge> = []
        var responsesInProgress: [UUID: ChallengeResponse] = [:] // Track responses by challengeId
        var isLoading: Bool = false
        var errorMessage: String?
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case fetchChallenges
        case challengesLoaded([Challenge])
        case startChallenge(UUID)
        case submitResponse(UUID, Data?) // challengeId, imageData (nil if no photo)
        case responseSubmitted(Result<ChallengeResponse, ChallengeResponseError>)
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

    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .path:
                return .none
            case .fetchChallenges:
                state.isLoading = true
                return .run { send in
                    await send(.challengesLoaded(Challenge.mockList))
                }
            case .challengesLoaded(let challenges):
                state.challenges = IdentifiedArray(uniqueElements: challenges)
                state.isLoading = false
                state.errorMessage = nil
                return .none
//            case .challengesLoaded(.failure(let error)):
//                state.isLoading = false
//                state.errorMessage = error.localizedDescription
//                return .none
            case .startChallenge(let challengeId):
                if state.responsesInProgress[challengeId] == nil {
                    let response = ChallengeResponse(
                        id: UUID(),
                        challengeId: challengeId,
                        cohouseId: "cohouse_alpha", // Replace with authenticated cohouseId
                        content: .noChoice,
                        status: .waiting,
                        submissionDate: Date()
                    )
                    state.responsesInProgress[challengeId] = response
                }
                return .none
            case .submitResponse(let challengeId, let imageData):
                guard let response = state.responsesInProgress[challengeId] else { return .none }
                state.isLoading = true
                return .run { send in
                    let result = await challengeResponseClient.submitResponse(response, imageData)
                    await send(.responseSubmitted(result))
                }
            case .responseSubmitted(.success(let response)):
                state.isLoading = false
                state.responsesInProgress.removeValue(forKey: response.challengeId)
                state.errorMessage = nil
                return .none
            case .responseSubmitted(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
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
                                ForEach(store.challenges) { challenge in
                                    ChallengeTileView(
                                        challenge: challenge,
                                        response: store.responsesInProgress[challenge.id],
                                        onStart: { store.send(.startChallenge(challenge.id)) },
                                        onSubmit: { imageData in store.send(.submitResponse(challenge.id, imageData)) }
                                    )
                                }
                            }
                        }
                        .onAppear {
                            UIScrollView.appearance().isPagingEnabled = true
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
        store: Store(initialState: ChallengeFeature.State(challenges: IdentifiedArray(uniqueElements: Challenge.mockList))) {
            ChallengeFeature()
        }
    )
}
