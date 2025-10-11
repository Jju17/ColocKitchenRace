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
        case challengesResponse([Challenge])
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
        Reduce {
            state,
            action in
            switch action {
                case .onAppear:
                    state.isLoading = true
                    return .run { send in
                        do {
                            let items = try await challengesClient.getAll()
                            await send(.challengesResponse(items))
                        } catch {
                            await send(.failed(error.localizedDescription))
                        }
                    }
                    
                case let .challengesResponse(challenges):
                    state.isLoading = false
                    state.errorMessage = nil
                    
                    guard let cohouseId = currentCohouse?.id.uuidString,
                          !cohouseId.isEmpty else {
                        state.challengeTiles = []
                        state.errorMessage = nil
                        return .none
                    }
                    
                    state.challengeTiles = IdentifiedArray(
                        uniqueElements: challenges.map {
                            ChallengeTileFeature.State(
                                id: $0.id,
                                challenge: $0,
                                cohouseId: cohouseId,
                                response: nil
                            )
                    })
                    return .none

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
