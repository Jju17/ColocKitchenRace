//
//  LeaderboardFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 10/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct LeaderboardFeatureTests {

    // MARK: - onAppear

    @Test("onAppear loads challenges and watches responses stream")
    func onAppear_startsLoadingAndWatchesResponses() async {
        let store = TestStore(
            initialState: LeaderboardFeature.State(
                myCohouseId: nil
            )
        ) {
            LeaderboardFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [] }
            $0.challengeResponseClient.watchAllValidatedResponses = {
                AsyncStream { continuation in
                    continuation.yield([])
                    continuation.finish()
                }
            }
        }

        // isLoading defaults to true, onAppear keeps it true → no state change
        await store.send(.onAppear)

        await store.receive(\.challengesLoaded)

        await store.receive(\.responsesUpdated) {
            $0.isLoading = false
            $0.entries = []
        }
    }

    // MARK: - responsesUpdated

    @Test("responsesUpdated with empty array results in empty leaderboard")
    func responsesUpdated_emptyArray() async {
        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: Challenge.mockList,
                isLoading: true,
                myCohouseId: nil
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated([])) {
            $0.isLoading = false
            $0.entries = []
        }
    }

    @Test("responsesUpdated with one response uses default 1 point when points is nil")
    func responsesUpdated_singleCohouse_defaultPoints() async {
        let challenge = Challenge(
            id: UUID(0),
            title: "Test Challenge",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: nil
        )

        let response = ChallengeResponse(
            id: UUID(1),
            challengeId: challenge.id,
            cohouseId: "cohouse_alpha",
            challengeTitle: challenge.title,
            cohouseName: "Zone 88",
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: [challenge],
                isLoading: true,
                myCohouseId: "cohouse_alpha"
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated([response])) {
            $0.isLoading = false
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_alpha",
                    cohouseName: "Zone 88",
                    score: 1,
                    validatedCount: 1,
                    rank: 1
                )
            ]
        }
    }

    @Test("responsesUpdated sums points correctly (nil defaults to 1, custom points used)")
    func responsesUpdated_singleCohouse_mixedPoints() async {
        let challenge1 = Challenge(
            id: UUID(0),
            title: "No Points",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: nil // → defaults to 1
        )

        let challenge2 = Challenge(
            id: UUID(1),
            title: "Five Points",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: 5
        )

        let response1 = ChallengeResponse(
            id: UUID(2),
            challengeId: challenge1.id,
            cohouseId: "cohouse_alpha",
            challengeTitle: challenge1.title,
            cohouseName: "Zone 88",
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        let response2 = ChallengeResponse(
            id: UUID(3),
            challengeId: challenge2.id,
            cohouseId: "cohouse_alpha",
            challengeTitle: challenge2.title,
            cohouseName: "Zone 88",
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: [challenge1, challenge2],
                isLoading: true,
                myCohouseId: nil
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated([response1, response2])) {
            $0.isLoading = false
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_alpha",
                    cohouseName: "Zone 88",
                    score: 6, // 1 + 5
                    validatedCount: 2,
                    rank: 1
                )
            ]
        }
    }

    @Test("responsesUpdated ranks multiple cohouses correctly by score descending")
    func responsesUpdated_multipleCohouses_ranking() async {
        let challenge1 = Challenge(
            id: UUID(0),
            title: "Basic",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: nil // 1 point
        )

        let challenge2 = Challenge(
            id: UUID(1),
            title: "High Value",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: 10
        )

        let challenge3 = Challenge(
            id: UUID(2),
            title: "Medium Value",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: 3
        )

        let responses = [
            // Alpha: challenge1 (1) + challenge2 (10) = 11
            ChallengeResponse(
                id: UUID(10),
                challengeId: challenge1.id,
                cohouseId: "cohouse_alpha",
                challengeTitle: challenge1.title,
                cohouseName: "Zone 88",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
            ChallengeResponse(
                id: UUID(11),
                challengeId: challenge2.id,
                cohouseId: "cohouse_alpha",
                challengeTitle: challenge2.title,
                cohouseName: "Zone 88",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
            // Beta: challenge1 (1) + challenge3 (3) = 4
            ChallengeResponse(
                id: UUID(12),
                challengeId: challenge1.id,
                cohouseId: "cohouse_beta",
                challengeTitle: challenge1.title,
                cohouseName: "Beta House",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
            ChallengeResponse(
                id: UUID(13),
                challengeId: challenge3.id,
                cohouseId: "cohouse_beta",
                challengeTitle: challenge3.title,
                cohouseName: "Beta House",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
            // Gamma: challenge1 (1) = 1
            ChallengeResponse(
                id: UUID(14),
                challengeId: challenge1.id,
                cohouseId: "cohouse_gamma",
                challengeTitle: challenge1.title,
                cohouseName: "Gamma Crew",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
        ]

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: [challenge1, challenge2, challenge3],
                isLoading: true,
                myCohouseId: "cohouse_beta"
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated(responses)) {
            $0.isLoading = false
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_alpha",
                    cohouseName: "Zone 88",
                    score: 11,
                    validatedCount: 2,
                    rank: 1
                ),
                LeaderboardEntry(
                    id: "cohouse_beta",
                    cohouseName: "Beta House",
                    score: 4,
                    validatedCount: 2,
                    rank: 2
                ),
                LeaderboardEntry(
                    id: "cohouse_gamma",
                    cohouseName: "Gamma Crew",
                    score: 1,
                    validatedCount: 1,
                    rank: 3
                ),
            ]
        }
    }

    @Test("responsesUpdated counts orphaned response with default 1 point")
    func responsesUpdated_orphanedResponse() async {
        let knownChallenge = Challenge(
            id: UUID(0),
            title: "Known Challenge",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: 3
        )

        let orphanedChallengeId = UUID(99) // Not in challenges list

        let responses = [
            ChallengeResponse(
                id: UUID(1),
                challengeId: knownChallenge.id,
                cohouseId: "cohouse_alpha",
                challengeTitle: knownChallenge.title,
                cohouseName: "Zone 88",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
            ChallengeResponse(
                id: UUID(2),
                challengeId: orphanedChallengeId,
                cohouseId: "cohouse_alpha",
                challengeTitle: "Ghost Challenge",
                cohouseName: "Zone 88",
                content: .noChoice,
                status: .validated,
                submissionDate: Date()
            ),
        ]

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: [knownChallenge],
                isLoading: true,
                myCohouseId: nil
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated(responses)) {
            $0.isLoading = false
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_alpha",
                    cohouseName: "Zone 88",
                    score: 4, // 3 (known) + 1 (orphaned, default)
                    validatedCount: 2,
                    rank: 1
                )
            ]
        }
    }

    @Test("responsesUpdated uses cohouseName from first response in group")
    func responsesUpdated_cohouseNameFromFirstResponse() async {
        let challenge = Challenge(
            id: UUID(0),
            title: "Test",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: nil
        )

        let response = ChallengeResponse(
            id: UUID(1),
            challengeId: challenge.id,
            cohouseId: "cohouse_mystery",
            challengeTitle: challenge.title,
            cohouseName: "My Cohouse Name",
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                challenges: [challenge],
                isLoading: true,
                myCohouseId: nil
            )
        ) {
            LeaderboardFeature()
        }

        await store.send(.responsesUpdated([response])) {
            $0.isLoading = false
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_mystery",
                    cohouseName: "My Cohouse Name",
                    score: 1,
                    validatedCount: 1,
                    rank: 1
                )
            ]
        }
    }

    @Test("onAppear loads challenges then stream receives multiple updates")
    func onAppear_multipleStreamUpdates() async {
        let challenge = Challenge(
            id: UUID(0),
            title: "Test",
            startDate: .distantPast,
            endDate: .distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            points: nil
        )

        let response = ChallengeResponse(
            id: UUID(1),
            challengeId: challenge.id,
            cohouseId: "cohouse_alpha",
            challengeTitle: challenge.title,
            cohouseName: "Zone 88",
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        let store = TestStore(
            initialState: LeaderboardFeature.State(
                myCohouseId: "cohouse_alpha"
            )
        ) {
            LeaderboardFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [challenge] }
            $0.challengeResponseClient.watchAllValidatedResponses = {
                AsyncStream { continuation in
                    // First update: empty
                    continuation.yield([])
                    // Second update: one response
                    continuation.yield([response])
                    continuation.finish()
                }
            }
        }

        // isLoading starts as true (default), onAppear keeps it true → no state change
        await store.send(.onAppear)

        // Challenges loaded
        await store.receive(\.challengesLoaded) {
            $0.challenges = [challenge]
        }

        // First update: empty
        await store.receive(\.responsesUpdated) {
            $0.isLoading = false
            $0.entries = []
        }

        // Second update: one response (now has challenges for points)
        await store.receive(\.responsesUpdated) {
            $0.entries = [
                LeaderboardEntry(
                    id: "cohouse_alpha",
                    cohouseName: "Zone 88",
                    score: 1,
                    validatedCount: 1,
                    rank: 1
                )
            ]
        }
    }
}
