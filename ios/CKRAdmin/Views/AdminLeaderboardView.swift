//
//  AdminLeaderboardView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 10/02/2026.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Leaderboard Entry

struct AdminLeaderboardEntry: Equatable, Identifiable {
    var id: String  // cohouseId
    var cohouseName: String
    var score: Int
    var validatedCount: Int
    var rank: Int
}

// MARK: - Feature

@Reducer
struct AdminLeaderboardFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [AdminLeaderboardEntry] = []
        var challenges: [Challenge] = []
        var isLoading = true
    }

    enum Action {
        case onAppear
        case challengesLoaded([Challenge])
        case responsesUpdated([ChallengeResponse])
    }

    @Dependency(\.challengeClient) var challengeClient
    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .merge(
                    // Load challenges for points mapping
                    .run { send in
                        let result = await challengeClient.getAll()
                        if case let .success(challenges) = result {
                            await send(.challengesLoaded(challenges))
                        }
                    },
                    // Watch validated responses in real-time
                    .run { send in
                        for await responses in challengeResponseClient.watchAllValidatedResponses() {
                            await send(.responsesUpdated(responses))
                        }
                    }
                )

            case let .challengesLoaded(challenges):
                state.challenges = challenges
                return .none

            case let .responsesUpdated(responses):
                state.isLoading = false

                // Build points map: challengeId -> points (default 1)
                let pointsMap = Dictionary(
                    uniqueKeysWithValues: state.challenges.map { ($0.id, $0.points ?? 1) }
                )

                // Group validated responses by cohouseId
                let grouped = Dictionary(grouping: responses, by: \.cohouseId)

                // Calculate scores
                var entries = grouped.map { (cohouseId, cohouseResponses) in
                    let score = cohouseResponses.reduce(0) { total, response in
                        total + (pointsMap[response.challengeId] ?? 1)
                    }
                    return AdminLeaderboardEntry(
                        id: cohouseId,
                        cohouseName: cohouseResponses.first?.cohouseName ?? "Unknown",
                        score: score,
                        validatedCount: cohouseResponses.count,
                        rank: 0
                    )
                }
                .sorted { $0.score > $1.score }

                // Assign ranks
                for i in entries.indices {
                    entries[i].rank = i + 1
                }

                state.entries = entries
                return .none
            }
        }
    }
}

// MARK: - View

struct AdminLeaderboardView: View {
    let store: StoreOf<AdminLeaderboardFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if store.isLoading {
                    ProgressView("Loading leaderboard…")
                } else if store.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No validated challenges yet")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        // Podium section
                        Section {
                            podiumView
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        // Full ranking
                        Section("Full ranking") {
                            ForEach(store.entries) { entry in
                                leaderboardRow(entry: entry)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Leaderboard")
            .onAppear { store.send(.onAppear) }
            .animation(.spring(duration: 0.4), value: store.entries)
        }
    }

    // MARK: - Podium

    @ViewBuilder
    private var podiumView: some View {
        let top3 = Array(store.entries.prefix(3))

        HStack(alignment: .bottom, spacing: 12) {
            if top3.count > 1 {
                podiumCard(entry: top3[1], medal: "🥈", height: 90)
            }
            if top3.count > 0 {
                podiumCard(entry: top3[0], medal: "🥇", height: 120)
            }
            if top3.count > 2 {
                podiumCard(entry: top3[2], medal: "🥉", height: 70)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    private func podiumCard(entry: AdminLeaderboardEntry, medal: String, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 28))

            Text(entry.cohouseName)
                .font(.subheadline.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(entry.score) pt\(entry.score > 1 ? "s" : "")")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("\(entry.validatedCount) challenge\(entry.validatedCount > 1 ? "s" : "")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Row

    private func leaderboardRow(entry: AdminLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.cohouseName)
                    .font(.body.bold())
                    .lineLimit(1)

                Text("\(entry.validatedCount) challenge\(entry.validatedCount > 1 ? "s" : "") validated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.score) pts")
                .font(.headline)
        }
    }
}

#Preview {
    AdminLeaderboardView(
        store: Store(
            initialState: AdminLeaderboardFeature.State(
                entries: [
                    AdminLeaderboardEntry(id: "1", cohouseName: "Les Colocs du Bonheur", score: 12, validatedCount: 5, rank: 1),
                    AdminLeaderboardEntry(id: "2", cohouseName: "La Maison Folle", score: 9, validatedCount: 4, rank: 2),
                    AdminLeaderboardEntry(id: "3", cohouseName: "Chez Nous", score: 7, validatedCount: 3, rank: 3),
                    AdminLeaderboardEntry(id: "4", cohouseName: "La Coloc Perchée", score: 5, validatedCount: 2, rank: 4),
                ],
                isLoading: false
            )
        ) {
            AdminLeaderboardFeature()
        }
    )
}
