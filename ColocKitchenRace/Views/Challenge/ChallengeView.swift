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
        var isLoading = false
        var errorMessage: String?
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case onAppear
        case challengesAndResponsesLoaded(Result<([Challenge], [ChallengeResponse]), Error>)
        case failed(String)
        case challengeTiles(IdentifiedActionOf<ChallengeTileFeature>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case switchToCohouseButtonTapped
        }
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

    @Shared(.cohouse) var currentCohouse: Cohouse?
    @Dependency(\.challengesClient) var challengesClient
    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    state.isLoading = true
                    state.errorMessage = nil

                    guard let cohouseId = currentCohouse?.id.uuidString,
                          !cohouseId.isEmpty
                    else {
                        state.isLoading = false
                        state.challengeTiles = []
                        state.errorMessage = nil
                        return .none
                    }

                    return .run { [cohouseId] send in
                        async let challengesTask: [Challenge] = {
                            do { return try await challengesClient.getAll() }
                            catch {
                                // Propagate the error via the action and exit early
                                await send(.challengesAndResponsesLoaded(.failure(error)))
                                return []
                            }
                        }()

                        async let responsesTask: Result<[ChallengeResponse], ChallengeResponseError> = challengeResponseClient.getAllForCohouse(cohouseId)

                        // Await results
                        let challenges = await challengesTask
                        // If challenges failed, we already sent the failure above; avoid double send
                        if challenges.isEmpty {
                            return
                        }

                        let responsesResult = await responsesTask

                        switch responsesResult {
                            case .success(let responsesList):
                                await send(.challengesAndResponsesLoaded(.success((challenges, responsesList))))
                            case .failure(let err):
                                await send(.challengesAndResponsesLoaded(.failure(err)))
                        }
                    }

                case let .challengesAndResponsesLoaded(result):
                    state.isLoading = false
                    switch result {
                        case let .success((challenges, responses)):
                            state.errorMessage = nil

                            guard let cohouse = currentCohouse else {
                                state.challengeTiles = []
                                return .none
                            }

                            // Index existing responses by challengeId for quick lookup
                            let responseByChallengeId = Dictionary(uniqueKeysWithValues: responses.map { ($0.challengeId, $0) })

                            state.challengeTiles = IdentifiedArray(
                                uniqueElements: challenges.map { challenge in
                                    let resp = responseByChallengeId[challenge.id]
                                    return ChallengeTileFeature.State(
                                        id: challenge.id,
                                        challenge: challenge,
                                        cohouseId: cohouse.id.uuidString,
                                        cohouseName: cohouse.name,
                                        response: resp,
                                        selectedAnswer: nil,
                                        isSubmitting: false,
                                        submitError: nil,
                                        picture: .init(),
                                        liveStatus: resp?.status
                                    )
                                }
                            )
                            return .none

                        case let .failure(error):
                            state.errorMessage = errorMessage(from: error)
                            state.challengeTiles = []
                            return .none
                    }

                case .failed(let msg):
                    state.isLoading = false
                    state.errorMessage = msg
                    return .none

                case .challengeTiles:
                    return .none

                case .path, .delegate:
                    return .none
            }
        }
        .forEach(\.challengeTiles, action: \.challengeTiles) { ChallengeTileFeature() }
    }
}

// Local helper to map errors to a displayable message
private func errorMessage(from error: any Error) -> String {
//    if let err = error as? ChallengesClientError {
//        switch err {
//            case .networkError: return "Network error. Please try again."
//            case .permissionDenied: return "Permission denied."
//            case .unknown(let msg): return msg
//        }
//    }
    if let err = error as? ChallengeResponseError {
        switch err {
            case .networkError: return "Network error. Please try again."
            case .permissionDenied: return "Permission denied."
            case .unknown(let msg): return msg
        }
    }
    return error.localizedDescription
}

struct ChallengeView: View {
    @Bindable var store: StoreOf<ChallengeFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack {
                if store.isLoading {
                  ProgressView("Loading challenges…")
                } else if let msg = store.errorMessage {
                  Text(msg).foregroundStyle(.red)
                } else if store.challengeTiles.isEmpty {
                  VStack(spacing: 12) {
                    Text("Rejoins ou crée une colocation pour participer aux challenges.")
                      .multilineTextAlignment(.center)
                      .foregroundStyle(.secondary)
                    Button("Aller à l’onglet Coloc") { store.send(.delegate(.switchToCohouseButtonTapped)) }
                      .buttonStyle(.borderedProminent)
                  }
                  .font(.custom("BaksoSapi", size: 14))
                  .padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(store.scope(state: \.challengeTiles, action: \.challengeTiles)) { tileStore in
                                ChallengeTileView(store: tileStore)
                            }
                        }
                    }
                    .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26)) { $0.isPagingEnabled = true }
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
            store.send(.onAppear)
        }
    }
}

#Preview {
    ChallengeView(
        store: Store(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }
    )
}
