//
//  LeaderboardView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 10/02/2026.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Equatable, Identifiable {
    var id: String  // cohouseId
    var cohouseName: String
    var score: Int
    var validatedCount: Int
    var rank: Int
}

// MARK: - Feature

@Reducer
struct LeaderboardFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [LeaderboardEntry] = []
        var challenges: [Challenge] = []
        var isLoading = true
        var myCohouseId: String?
    }

    enum Action {
        case onAppear
        case challengesLoaded([Challenge])
        case responsesUpdated([ChallengeResponse])
    }

    @Dependency(\.challengesClient) var challengesClient
    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .merge(
                    // Load challenges for points mapping
                    .run { send in
                        if let challenges = try? await challengesClient.getAll() {
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
                    return LeaderboardEntry(
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

struct LeaderboardView: View {
    let store: StoreOf<LeaderboardFeature>

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if store.isLoading {
                ProgressView("Loading leaderboard…")
                    .font(.custom("BaksoSapi", size: 18))
            } else if store.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No validated challenges yet")
                        .font(.custom("BaksoSapi", size: 18))
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Podium for top 3
                        podiumView

                        // Remaining entries
                        if store.entries.count > 3 {
                            Divider()
                                .padding(.vertical, 8)

                            LazyVStack(spacing: 0) {
                                ForEach(store.entries.dropFirst(3)) { entry in
                                    leaderboardRow(entry: entry)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .animation(.spring(duration: 0.4), value: store.entries)
    }

    // MARK: - Podium

    @ViewBuilder
    private var podiumView: some View {
        let top3 = Array(store.entries.prefix(3))

        VStack(spacing: 16) {
            // Medals row
            HStack(alignment: .bottom, spacing: 16) {
                if top3.count > 1 {
                    podiumCard(entry: top3[1], medal: "🥈", height: 100)
                }
                if top3.count > 0 {
                    podiumCard(entry: top3[0], medal: "🥇", height: 130)
                }
                if top3.count > 2 {
                    podiumCard(entry: top3[2], medal: "🥉", height: 80)
                }
            }
            .padding(.top, 8)
        }
    }

    private func podiumCard(entry: LeaderboardEntry, medal: String, height: CGFloat) -> some View {
        let isMyCohouse = entry.id == store.myCohouseId

        return VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 32))

            Text(entry.cohouseName)
                .font(.custom("BaksoSapi", size: 14))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(entry.score) pt\(entry.score > 1 ? "s" : "")")
                .font(.custom("BaksoSapi", size: 20))
                .foregroundStyle(.primary)

            Text("\(entry.validatedCount) challenge\(entry.validatedCount > 1 ? "s" : "")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isMyCohouse ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isMyCohouse ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Row

    private func leaderboardRow(entry: LeaderboardEntry) -> some View {
        let isMyCohouse = entry.id == store.myCohouseId

        return HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.custom("BaksoSapi", size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.cohouseName)
                    .font(.custom("BaksoSapi", size: 16))
                    .lineLimit(1)

                Text("\(entry.validatedCount) challenge\(entry.validatedCount > 1 ? "s" : "") validated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.score) pts")
                .font(.custom("BaksoSapi", size: 18))
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMyCohouse ? Color.blue.opacity(0.08) : Color.clear)
        )
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(
            store: Store(
                initialState: LeaderboardFeature.State(
                    entries: [
                        LeaderboardEntry(id: "1", cohouseName: "Les Colocs du Bonheur", score: 12, validatedCount: 5, rank: 1),
                        LeaderboardEntry(id: "2", cohouseName: "La Maison Folle", score: 9, validatedCount: 4, rank: 2),
                        LeaderboardEntry(id: "3", cohouseName: "Chez Nous", score: 7, validatedCount: 3, rank: 3),
                        LeaderboardEntry(id: "4", cohouseName: "La Coloc Perchée", score: 5, validatedCount: 2, rank: 4),
                        LeaderboardEntry(id: "5", cohouseName: "Les Joyeux Lurons", score: 3, validatedCount: 1, rank: 5),
                    ],
                    isLoading: false,
                    myCohouseId: "2"
                )
            ) {
                LeaderboardFeature()
            }
        )
    }
}
