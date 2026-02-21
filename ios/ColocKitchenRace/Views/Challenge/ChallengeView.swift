//
//  ChallengeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Filter

enum ChallengeFilter: String, CaseIterable, Equatable {
    case all, todo, inProgress, waitingForReview, reviewed

    var label: String {
        switch self {
        case .all:               "All"
        case .todo:              "📋 To do"
        case .inProgress:        "🔥 In progress"
        case .waitingForReview:  "⏳ Waiting"
        case .reviewed:          "✅ Reviewed"
        }
    }
}

@Reducer
struct ChallengeFeature {
    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        var challengeTiles: IdentifiedArrayOf<ChallengeTileFeature.State> = []
        var selectedFilter: ChallengeFilter = .all
        var hasCohouse = false
        var isLoading = false
        var errorMessage: String?
        @Presents var leaderboard: LeaderboardFeature.State?
        var pinnedTileIDs: Set<UUID> = []

        // MARK: - Filtered & Sorted tiles

        var filteredTiles: IdentifiedArrayOf<ChallengeTileFeature.State> {
            let filtered: [ChallengeTileFeature.State] = challengeTiles.filter { tile in
                if pinnedTileIDs.contains(tile.id) { return true }
                return switch selectedFilter {
                case .all:              true
                case .todo:             tile.response == nil
                case .inProgress:       tile.response != nil && tile.liveStatus == nil
                case .waitingForReview: tile.liveStatus == .waiting
                case .reviewed:         tile.liveStatus == .validated
                                        || tile.liveStatus == .invalidated
                }
            }

            let sorted = filtered.sorted { a, b in
                // Primary sort: inProgress → waitingForReview → todo → reviewed
                let order: (ChallengeTileFeature.State) -> Int = { tile in
                    if tile.response != nil && tile.liveStatus == nil { return 0 }          // inProgress
                    if tile.liveStatus == .waiting { return 1 }                             // waitingForReview
                    if tile.response == nil { return 2 }                                    // todo
                    return 3                                                                // reviewed
                }
                let ao = order(a), bo = order(b)
                if ao != bo { return ao < bo }
                // Secondary sort: soonest deadline first
                return a.challenge.endDate < b.challenge.endDate
            }

            return IdentifiedArray(uniqueElements: sorted)
        }
    }

    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case onAppear
        case challengesAndResponsesLoaded(Result<([Challenge], [ChallengeResponse]), Error>)
        case failed(String)
        case filterChanged(ChallengeFilter)
        case challengeTiles(IdentifiedActionOf<ChallengeTileFeature>)
        case leaderboardButtonTapped
        case leaderboard(PresentationAction<LeaderboardFeature.Action>)
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
                state.pinnedTileIDs = []
                state.hasCohouse = currentCohouse != nil

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

                    // Index responses by challengeId for quick lookup
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

            // MARK: - Filter
            case let .filterChanged(filter):
                state.selectedFilter = filter
                state.pinnedTileIDs = []
                return .none

            // MARK: - Explicit failure
            case let .failed(msg):
                state.isLoading = false
                state.errorMessage = msg
                return .none

            // MARK: - Leaderboard
            case .leaderboardButtonTapped:
                state.leaderboard = LeaderboardFeature.State(
                    myCohouseId: currentCohouse?.id.uuidString
                )
                return .none

            // MARK: - Child tile pinning

            case let .challengeTiles(.element(id: tileID, action: .startTapped)):
                if state.selectedFilter != .all {
                    state.pinnedTileIDs.insert(tileID)
                }
                return .none

            case let .challengeTiles(.element(id: tileID, action: .delegate(.responseSubmitted))):
                state.pinnedTileIDs.remove(tileID)
                return .none

            // MARK: - Child / navigation passthrough
            case .challengeTiles, .path, .delegate, .leaderboard:
                return .none
            }
        }
        .forEach(\.challengeTiles, action: \.challengeTiles) { ChallengeTileFeature() }
        .ifLet(\.$leaderboard, action: \.leaderboard) { LeaderboardFeature() }
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

// MARK: - View

struct ChallengeView: View {
    @Bindable var store: StoreOf<ChallengeFeature>
    @State private var currentPage: UUID?

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                if store.isLoading {
                    Spacer()
                    ProgressView("Loading challenges…")
                        .font(.custom("BaksoSapi", size: 18))
                    Spacer()
                }
                else if let msg = store.errorMessage {
                    Spacer()
                    Text(msg).foregroundStyle(.red)
                        .font(.custom("BaksoSapi", size: 16))
                    Spacer()
                }
                else if !store.hasCohouse {
                    Spacer()
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
                    Spacer()
                }
                else if store.challengeTiles.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "flag")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No challenges")
                            .font(.custom("BaksoSapi", size: 20))
                            .foregroundStyle(.secondary)
                        Text("Stay tuned!")
                            .font(.custom("BaksoSapi", size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                else {
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ChallengeFilter.allCases, id: \.self) { filter in
                                FilterChipView(
                                    title: filter.label,
                                    isSelected: store.selectedFilter == filter
                                ) {
                                    store.send(.filterChanged(filter))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    if store.filteredTiles.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No \(store.selectedFilter.label.lowercased()) challenges")
                                .font(.custom("BaksoSapi", size: 18))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        SnapPagingContainer(itemWidth: UIScreen.main.bounds.width - 32, currentPage: $currentPage) {
                            ForEach(Array(store.filteredTiles.enumerated()), id: \.element.id) { _, tileState in
                                if let tileStore = store.scope(state: \.challengeTiles[id: tileState.id], action: \.challengeTiles[id: tileState.id]) {
                                    ChallengeTileView(store: tileStore, colorIndex: stableColorIndex(for: tileState.id))
                                }
                            }
                        }

                        // Page dots
                        PageDotsView(
                            total: store.filteredTiles.count,
                            currentIndex: store.filteredTiles.firstIndex(where: { $0.id == currentPage }) ?? 0
                        )
                        .padding(.bottom, 8)
                    }
                }
            }
            .background(Color(.systemBackground))
            .onChange(of: store.selectedFilter) { _, _ in
                currentPage = store.filteredTiles.first?.id
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .font(.custom("BaksoSapi", size: 32))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.leaderboardButtonTapped)
                    } label: {
                        Image(systemName: "trophy.fill")
                    }
                }
            }
            .sheet(item: $store.scope(state: \.leaderboard, action: \.leaderboard)) { leaderboardStore in
                NavigationStack {
                    LeaderboardView(store: leaderboardStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    store.send(.leaderboard(.dismiss))
                                }
                            }
                        }
                }
            }
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

    /// Derive a stable color index from the tile's UUID so it never changes on re-sort.
    private func stableColorIndex(for id: UUID) -> Int {
        abs(id.hashValue)
    }
}

#Preview {
    ChallengeView(
        store: Store(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }
    )
}
