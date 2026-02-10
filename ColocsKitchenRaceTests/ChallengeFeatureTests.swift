//
//  ChallengeFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct ChallengeFeatureTests {

    // MARK: - No Cohouse

    @Test("onAppear without cohouse clears tiles without loading")
    func onAppear_noCohouse() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }

        // Pas de cohouse → on vide les tiles, pas de loading, pas d'effect
        await store.send(.onAppear)
    }

    // MARK: - Successful Load

    @Test("onAppear with cohouse loads challenges and responses")
    func onAppear_withCohouse() async {
        @Shared(.cohouse) var cohouse
        let mockCohouse = Cohouse.mock
        $cohouse.withLock { $0 = mockCohouse }

        let challenge = Challenge.mock
        let response = ChallengeResponse(
            id: UUID(),
            challengeId: challenge.id,
            cohouseId: mockCohouse.id.uuidString,
            challengeTitle: challenge.title,
            cohouseName: mockCohouse.name,
            content: .noChoice,
            status: .waiting,
            submissionDate: Date()
        )

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [challenge] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([response]) }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.challengesAndResponsesLoaded) {
            $0.isLoading = false
            $0.challengeTiles = IdentifiedArray(uniqueElements: [
                ChallengeTileFeature.State(
                    id: challenge.id,
                    challenge: challenge,
                    cohouseId: mockCohouse.id.uuidString,
                    cohouseName: mockCohouse.name,
                    response: response,
                    liveStatus: response.status
                )
            ])
        }
    }

    // MARK: - Error Handling

    @Test("onAppear with response error shows error message")
    func onAppear_responseError() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { Challenge.mockList }
            $0.challengeResponseClient.getAllForCohouse = { _ in
                .failure(.networkError)
            }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.challengesAndResponsesLoaded) {
            $0.isLoading = false
            $0.errorMessage = "Network error. Please try again."
            $0.challengeTiles = []
        }
    }

    // MARK: - Empty challenges (was a bug, now fixed)

    @Test("onAppear with 0 challenges shows empty state correctly")
    func onAppear_emptyChallenges() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([]) }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Le refactor corrige le bug : on reçoit bien le résultat même si 0 challenges
        await store.receive(\.challengesAndResponsesLoaded) {
            $0.isLoading = false
            $0.challengeTiles = []
        }
    }

    // MARK: - Delegate

    @Test("switchToCohouseButtonTapped delegate is forwarded")
    func switchToCohouse() async {
        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }

        await store.send(.delegate(.switchToCohouseButtonTapped))
    }

    // MARK: - Failed action

    @Test("failed action sets error message and stops loading")
    func failedAction() async {
        let store = TestStore(initialState: ChallengeFeature.State(isLoading: true)) {
            ChallengeFeature()
        }

        await store.send(.failed("Something went wrong")) {
            $0.isLoading = false
            $0.errorMessage = "Something went wrong"
        }
    }

    // MARK: - Leaderboard

    @Test("leaderboardButtonTapped presents leaderboard with cohouseId")
    func leaderboardButtonTapped_presentsWithCohouseId() async {
        @Shared(.cohouse) var cohouse
        let mockCohouse = Cohouse.mock
        $cohouse.withLock { $0 = mockCohouse }

        let store = TestStore(
            initialState: ChallengeFeature.State()
        ) {
            ChallengeFeature()
        }

        await store.send(.leaderboardButtonTapped) {
            $0.leaderboard = LeaderboardFeature.State(
                myCohouseId: mockCohouse.id.uuidString
            )
        }
    }

    @Test("leaderboardButtonTapped without cohouse sets nil myCohouseId")
    func leaderboardButtonTapped_noCohouse() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        let store = TestStore(
            initialState: ChallengeFeature.State()
        ) {
            ChallengeFeature()
        }

        await store.send(.leaderboardButtonTapped) {
            $0.leaderboard = LeaderboardFeature.State(
                myCohouseId: nil
            )
        }
    }

    @Test("leaderboard dismiss clears leaderboard state")
    func leaderboard_dismiss() async {
        let store = TestStore(
            initialState: ChallengeFeature.State(
                leaderboard: LeaderboardFeature.State(
                    myCohouseId: nil
                )
            )
        ) {
            ChallengeFeature()
        }

        await store.send(.leaderboard(.dismiss)) {
            $0.leaderboard = nil
        }
    }
}
