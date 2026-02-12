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

        // No cohouse → hasCohouse stays false, We empty tiles, no loading, no effect
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
            $0.hasCohouse = true
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
            $0.hasCohouse = true
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.challengesAndResponsesLoaded) {
            $0.isLoading = false
            $0.errorMessage = "Network error. Please try again."
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

    // MARK: - hasCohouse distinction

    @Test("onAppear with cohouse but no challenges → hasCohouse true, tiles empty, shows 'No challenges'")
    func onAppear_cohouseButNoChallenges_showsNoChallenges() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([]) }
        }

        await store.send(.onAppear) {
            $0.hasCohouse = true
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.challengesAndResponsesLoaded) {
            $0.isLoading = false
            $0.challengeTiles = []
        }

        // After this: hasCohouse == true && challengeTiles.isEmpty → view shows "No challenges"
        // NOT the "Join or create a cohouse" message
        #expect(store.state.hasCohouse == true)
        #expect(store.state.challengeTiles.isEmpty)
    }

    @Test("onAppear without cohouse → hasCohouse false, tiles empty, shows 'Join a cohouse'")
    func onAppear_noCohouse_showsJoinCohouse() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }

        await store.send(.onAppear)

        // hasCohouse == false && challengeTiles.isEmpty → view shows "Join or create a cohouse"
        #expect(store.state.hasCohouse == false)
        #expect(store.state.challengeTiles.isEmpty)
    }

    // MARK: - Helpers

    private func makeTile(
        id: UUID = UUID(),
        endDate: Date = Date.from(year: 2026, month: 6, day: 1, hour: 23),
        response: ChallengeResponse? = nil,
        liveStatus: ChallengeResponseStatus? = nil
    ) -> ChallengeTileFeature.State {
        let challenge = Challenge(
            id: id,
            title: "Test Challenge",
            startDate: Date.from(year: 2024, month: 1, day: 1, hour: 0),
            endDate: endDate,
            body: "Test body",
            content: .noChoice(NoChoiceContent())
        )
        return ChallengeTileFeature.State(
            id: id,
            challenge: challenge,
            cohouseId: "cohouse_test",
            cohouseName: "Test Cohouse",
            response: response,
            liveStatus: liveStatus
        )
    }

    private func makeResponse(
        challengeId: UUID,
        status: ChallengeResponseStatus = .waiting
    ) -> ChallengeResponse {
        ChallengeResponse(
            id: UUID(),
            challengeId: challengeId,
            cohouseId: "cohouse_test",
            challengeTitle: "Test Challenge",
            cohouseName: "Test Cohouse",
            content: .noChoice,
            status: status,
            submissionDate: Date()
        )
    }

    // MARK: - Filter changed

    @Test("filterChanged updates selectedFilter")
    func filterChanged_updatesSelectedFilter() async {
        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        }

        await store.send(.filterChanged(.todo)) {
            $0.selectedFilter = .todo
        }

        await store.send(.filterChanged(.inProgress)) {
            $0.selectedFilter = .inProgress
        }

        await store.send(.filterChanged(.reviewed)) {
            $0.selectedFilter = .reviewed
        }

        await store.send(.filterChanged(.all)) {
            $0.selectedFilter = .all
        }
    }

    // MARK: - Filtered tiles by user state

    @Test("filteredTiles todo returns only tiles without response")
    func filteredTiles_todo() {
        let todoId = UUID()
        let inProgressId = UUID()
        let waitingId = UUID()
        let reviewedId = UUID()

        let inProgressResp = makeResponse(challengeId: inProgressId, status: .waiting)
        let waitingResp = makeResponse(challengeId: waitingId, status: .waiting)
        let reviewedResp = makeResponse(challengeId: reviewedId, status: .validated)

        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: todoId, response: nil, liveStatus: nil),
                makeTile(id: inProgressId, response: inProgressResp, liveStatus: nil),
                makeTile(id: waitingId, response: waitingResp, liveStatus: .waiting),
                makeTile(id: reviewedId, response: reviewedResp, liveStatus: .validated),
            ]),
            selectedFilter: .todo
        )

        #expect(state.filteredTiles.count == 1)
        #expect(state.filteredTiles[0].id == todoId)
    }

    @Test("filteredTiles inProgress returns only tiles started but not yet submitted")
    func filteredTiles_inProgress() {
        let todoId = UUID()
        let inProgressId = UUID()
        let waitingId = UUID()
        let reviewedId = UUID()

        let inProgressResp = makeResponse(challengeId: inProgressId, status: .waiting)
        let waitingResp = makeResponse(challengeId: waitingId, status: .waiting)
        let reviewedResp = makeResponse(challengeId: reviewedId, status: .validated)

        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: todoId, response: nil, liveStatus: nil),
                makeTile(id: inProgressId, response: inProgressResp, liveStatus: nil),
                makeTile(id: waitingId, response: waitingResp, liveStatus: .waiting),
                makeTile(id: reviewedId, response: reviewedResp, liveStatus: .validated),
            ]),
            selectedFilter: .inProgress
        )

        #expect(state.filteredTiles.count == 1)
        #expect(state.filteredTiles[0].id == inProgressId)
    }

    @Test("filteredTiles waitingForReview returns only submitted tiles awaiting admin review")
    func filteredTiles_waitingForReview() {
        let todoId = UUID()
        let inProgressId = UUID()
        let waitingId = UUID()
        let reviewedId = UUID()

        let inProgressResp = makeResponse(challengeId: inProgressId, status: .waiting)
        let waitingResp = makeResponse(challengeId: waitingId, status: .waiting)
        let reviewedResp = makeResponse(challengeId: reviewedId, status: .validated)

        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: todoId, response: nil, liveStatus: nil),
                makeTile(id: inProgressId, response: inProgressResp, liveStatus: nil),
                makeTile(id: waitingId, response: waitingResp, liveStatus: .waiting),
                makeTile(id: reviewedId, response: reviewedResp, liveStatus: .validated),
            ]),
            selectedFilter: .waitingForReview
        )

        #expect(state.filteredTiles.count == 1)
        #expect(state.filteredTiles[0].id == waitingId)
    }

    @Test("filteredTiles reviewed returns only validated and invalidated tiles")
    func filteredTiles_reviewed() {
        let todoId = UUID()
        let waitingId = UUID()
        let validatedId = UUID()
        let invalidatedId = UUID()

        let waitingResp = makeResponse(challengeId: waitingId, status: .waiting)
        let validatedResp = makeResponse(challengeId: validatedId, status: .validated)
        let invalidatedResp = makeResponse(challengeId: invalidatedId, status: .invalidated)

        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: todoId, response: nil, liveStatus: nil),
                makeTile(id: waitingId, response: waitingResp, liveStatus: .waiting),
                makeTile(id: validatedId, response: validatedResp, liveStatus: .validated),
                makeTile(id: invalidatedId, response: invalidatedResp, liveStatus: .invalidated),
            ]),
            selectedFilter: .reviewed
        )

        #expect(state.filteredTiles.count == 2)
        let ids = state.filteredTiles.map(\.id)
        #expect(ids.contains(validatedId))
        #expect(ids.contains(invalidatedId))
    }

    @Test("filteredTiles all returns all tiles sorted by user state then endDate")
    func filteredTiles_all_sortedByUserStateThenEndDate() {
        let todoId = UUID()
        let inProgressId = UUID()
        let waitingId = UUID()
        let reviewedId = UUID()

        let inProgressResp = makeResponse(challengeId: inProgressId, status: .waiting)
        let waitingResp = makeResponse(challengeId: waitingId, status: .waiting)
        let reviewedResp = makeResponse(challengeId: reviewedId, status: .validated)

        // Insert in wrong order: reviewed, todo, waiting, inProgress
        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: reviewedId, endDate: Date.from(year: 2026, month: 3, day: 1, hour: 23), response: reviewedResp, liveStatus: .validated),
                makeTile(id: todoId, endDate: Date.from(year: 2026, month: 4, day: 1, hour: 23), response: nil, liveStatus: nil),
                makeTile(id: waitingId, endDate: Date.from(year: 2026, month: 5, day: 1, hour: 23), response: waitingResp, liveStatus: .waiting),
                makeTile(id: inProgressId, endDate: Date.from(year: 2026, month: 6, day: 1, hour: 23), response: inProgressResp, liveStatus: nil),
            ]),
            selectedFilter: .all
        )

        // Expected order: inProgress → waitingForReview → todo → reviewed
        #expect(state.filteredTiles.count == 4)
        #expect(state.filteredTiles[0].id == inProgressId)
        #expect(state.filteredTiles[1].id == waitingId)
        #expect(state.filteredTiles[2].id == todoId)
        #expect(state.filteredTiles[3].id == reviewedId)
    }

    @Test("filteredTiles sorts by endDate within same user state")
    func filteredTiles_sortsByEndDateWithinSameState() {
        let earlyId = UUID()
        let lateId = UUID()

        let earlyResp = makeResponse(challengeId: earlyId, status: .waiting)
        let lateResp = makeResponse(challengeId: lateId, status: .waiting)

        // Two waitingForReview tiles with different endDates, inserted late first
        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: lateId, endDate: Date.from(year: 2026, month: 9, day: 1, hour: 23), response: lateResp, liveStatus: .waiting),
                makeTile(id: earlyId, endDate: Date.from(year: 2026, month: 3, day: 1, hour: 23), response: earlyResp, liveStatus: .waiting),
            ]),
            selectedFilter: .waitingForReview
        )

        // Soonest deadline first
        #expect(state.filteredTiles.count == 2)
        #expect(state.filteredTiles[0].id == earlyId)
        #expect(state.filteredTiles[1].id == lateId)
    }

    // MARK: - Pinned Tiles

    @Test("startTapped on child tile pins it when filter is not .all")
    func startTapped_pinsWhenFiltered() async {
        let tileId = UUID()
        let challenge = Challenge(
            id: tileId,
            title: "Test",
            startDate: Date.distantPast,
            endDate: Date.distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent())
        )

        let store = TestStore(
            initialState: ChallengeFeature.State(
                challengeTiles: IdentifiedArray(uniqueElements: [
                    ChallengeTileFeature.State(
                        id: tileId,
                        challenge: challenge,
                        cohouseId: "cohouse-1",
                        cohouseName: "Test House"
                    )
                ]),
                selectedFilter: .todo
            )
        ) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengeResponseClient.watchStatus = { _, _ in
                AsyncStream { $0.finish() }
            }
            $0.challengeResponseClient.submit = { $0 }
            $0.date = .constant(Date())
        }
        store.exhaustivity = .off

        await store.send(.challengeTiles(.element(id: tileId, action: .startTapped)))

        #expect(store.state.pinnedTileIDs == [tileId])
    }

    @Test("startTapped does NOT pin when filter is .all")
    func startTapped_doesNotPinWhenAll() async {
        let tileId = UUID()
        let challenge = Challenge(
            id: tileId,
            title: "Test",
            startDate: Date.distantPast,
            endDate: Date.distantFuture,
            body: "Body",
            content: .noChoice(NoChoiceContent())
        )

        let store = TestStore(
            initialState: ChallengeFeature.State(
                challengeTiles: IdentifiedArray(uniqueElements: [
                    ChallengeTileFeature.State(
                        id: tileId,
                        challenge: challenge,
                        cohouseId: "cohouse-1",
                        cohouseName: "Test House"
                    )
                ]),
                selectedFilter: .all
            )
        ) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengeResponseClient.watchStatus = { _, _ in
                AsyncStream { $0.finish() }
            }
            $0.challengeResponseClient.submit = { $0 }
            $0.date = .constant(Date())
        }
        store.exhaustivity = .off

        await store.send(.challengeTiles(.element(id: tileId, action: .startTapped)))

        #expect(store.state.pinnedTileIDs.isEmpty)
    }

    @Test("responseSubmitted on child tile unpins it")
    func responseSubmitted_unpins() async {
        let tileId = UUID()
        let resp = makeResponse(challengeId: tileId)

        let store = TestStore(
            initialState: ChallengeFeature.State(
                challengeTiles: IdentifiedArray(uniqueElements: [
                    makeTile(id: tileId, response: resp, liveStatus: .waiting)
                ]),
                selectedFilter: .todo,
                pinnedTileIDs: [tileId]
            )
        ) {
            ChallengeFeature()
        }
        store.exhaustivity = .off

        await store.send(.challengeTiles(.element(id: tileId, action: .delegate(.responseSubmitted(resp)))))

        #expect(store.state.pinnedTileIDs.isEmpty)
    }

    @Test("filterChanged clears pinnedTileIDs")
    func filterChanged_clearsPinned() async {
        let tileId = UUID()

        let store = TestStore(
            initialState: ChallengeFeature.State(pinnedTileIDs: [tileId])
        ) {
            ChallengeFeature()
        }

        await store.send(.filterChanged(.inProgress)) {
            $0.selectedFilter = .inProgress
            $0.pinnedTileIDs = []
        }
    }

    @Test("onAppear clears pinnedTileIDs")
    func onAppear_clearsPinned() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        let store = TestStore(
            initialState: ChallengeFeature.State(pinnedTileIDs: [UUID()])
        ) {
            ChallengeFeature()
        }

        await store.send(.onAppear) {
            $0.pinnedTileIDs = []
        }
    }

    @Test("pinned tile remains in filteredTiles even when state no longer matches filter")
    func pinnedTile_remainsVisible() {
        let todoId = UUID()
        let startedId = UUID()

        let startedResp = makeResponse(challengeId: startedId, status: .waiting)

        let state = ChallengeFeature.State(
            challengeTiles: IdentifiedArray(uniqueElements: [
                makeTile(id: todoId, response: nil, liveStatus: nil),
                makeTile(id: startedId, response: startedResp, liveStatus: .waiting),
            ]),
            selectedFilter: .todo,
            pinnedTileIDs: [startedId]
        )

        // startedId has a response (wouldn't match .todo) but is pinned → still visible
        #expect(state.filteredTiles.count == 2)
        let ids = state.filteredTiles.map(\.id)
        #expect(ids.contains(todoId))
        #expect(ids.contains(startedId))
    }
}
