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
    struct State: Equatable {
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
        enum State: Equatable {
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

            // MARK: - onAppear
            case .onAppear:
                // No cohouse -> We empty the tiles, nothing to load
                guard let cohouseId = currentCohouse?.id.uuidString,
                      !cohouseId.isEmpty
                else {
                    state.challengeTiles = []
                    return .none
                }

                // Start loading
                state.isLoading = true
                state.errorMessage = nil

                return .run { [cohouseId] send in
                    do {
                        // Parallel fetch : challenges + cohouse answers
                        async let challengesTask = challengesClient.getAll()
                        async let responsesTask = challengeResponseClient.getAllForCohouse(cohouseId)

                        let challenges = try await challengesTask
                        let responsesResult = await responsesTask

                        switch responsesResult {
                        case let .success(responses):
                            await send(.challengesAndResponsesLoaded(.success((challenges, responses))))
                        case let .failure(error):
                            await send(.challengesAndResponsesLoaded(.failure(error)))
                        }
                    } catch {
                        await send(.challengesAndResponsesLoaded(.failure(error)))
                    }
                }

            // MARK: - Data loaded
            case let .challengesAndResponsesLoaded(result):
                state.isLoading = false

                switch result {
                case let .success((challenges, responses)):
                    guard let cohouse = currentCohouse else {
                        state.challengeTiles = []
                        return .none
                    }

                    // Index des réponses par challengeId pour lookup rapide
                    let responseByChallenge = Dictionary(
                        uniqueKeysWithValues: responses.map { ($0.challengeId, $0) }
                    )

                    state.challengeTiles = IdentifiedArray(
                        uniqueElements: challenges.map { challenge in
                            let resp = responseByChallenge[challenge.id]
                            return ChallengeTileFeature.State(
                                id: challenge.id,
                                challenge: challenge,
                                cohouseId: cohouse.id.uuidString,
                                cohouseName: cohouse.name,
                                response: resp,
                                liveStatus: resp?.status
                            )
                        }
                    )
                    return .none

                case let .failure(error):
                    state.errorMessage = Self.errorMessage(from: error)
                    state.challengeTiles = []
                    return .none
                }

            // MARK: - Explicit failure
            case let .failed(msg):
                state.isLoading = false
                state.errorMessage = msg
                return .none

            // MARK: - Child / navigation passthrough
            case .challengeTiles, .path, .delegate:
                return .none
            }
        }
        .forEach(\.challengeTiles, action: \.challengeTiles) { ChallengeTileFeature() }
    }

    // MARK: - Helpers

    static func errorMessage(from error: any Error) -> String {
        if let err = error as? ChallengeResponseError {
            switch err {
            case .networkError: return "Network error. Please try again."
            case .permissionDenied: return "Permission denied."
            case .unknown(let msg): return msg
            }
        }
        return error.localizedDescription
    }
}

struct ChallengeView: View {
    @Bindable var store: StoreOf<ChallengeFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if store.isLoading {
                    ProgressView("Loading challenges…")
                        .font(.custom("BaksoSapi", size: 18))
                }
                else if let msg = store.errorMessage {
                    Text(msg).foregroundStyle(.red)
                        .font(.custom("BaksoSapi", size: 16))
                }
                else if store.challengeTiles.isEmpty {
                    VStack(spacing: 20) {
                        Text("Join or create a cohouse\nto participate in challenges.")
                            .font(.custom("BaksoSapi", size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Go to cohouse tab") {
                            store.send(.delegate(.switchToCohouseButtonTapped))
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.custom("BaksoSapi", size: 16))
                    }
                    .padding()
                }
                else {
                    SnapPagingContainer(itemWidth: UIScreen.main.bounds.width * 0.90) {
                        ForEachStore(store.scope(state: \.challengeTiles, action: \.challengeTiles)) { tileStore in
                            ChallengeTileView(store: tileStore)
                        }
                    }
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .font(.custom("BaksoSapi", size: 32)) // Titre principal
        } destination: { store in
            switch store.state {
                case .profile:
                    if let store = store.scope(state: \.profile, action: \.profile) {
                        UserProfileDetailView(store: store)
                    }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

#Preview {
    ChallengeView(
        store: Store(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }
    )
}
