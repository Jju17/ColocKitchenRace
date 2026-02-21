//
//  PlanningFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 13/02/2026.
//

import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import ColocsKitchenRace

@MainActor
struct PlanningFeatureTests {

    // MARK: - Helpers

    private static func makeMockPlanning() -> CKRMyPlanning {
        CKRMyPlanning(
            apero: PlanningStep(
                role: .visitor,
                cohouseName: "Les Colocs du 42",
                address: "Rue de la Loi 42, 1000 Bruxelles",
                hostPhone: "+32 471 123456",
                visitorPhone: "+32 472 654321",
                totalPeople: 8,
                dietarySummary: ["Végétarien": 2],
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                endTime: Date(timeIntervalSince1970: 1_700_007_200)
            ),
            diner: PlanningStep(
                role: .host,
                cohouseName: "Zone 88",
                address: "Avenue Louise 88, 1050 Ixelles",
                hostPhone: "+32 472 654321",
                visitorPhone: "+32 473 111222",
                totalPeople: 6,
                dietarySummary: ["Sans gluten": 1],
                startTime: Date(timeIntervalSince1970: 1_700_010_000),
                endTime: Date(timeIntervalSince1970: 1_700_017_200)
            ),
            party: PartyInfo(
                name: "TEUF",
                address: "Grand Place 1, 1000 Bruxelles",
                startTime: Date(timeIntervalSince1970: 1_700_020_000),
                endTime: Date(timeIntervalSince1970: 1_700_038_000),
                note: "Pas de bracelet, pas d'entrée !"
            )
        )
    }

    private static func makeRevealedGame(cohouseId: String) -> CKRGame {
        CKRGame(
            startCKRCountdown: Date.distantPast,
            nextGameDate: Date.distantFuture,
            registrationDeadline: Date.distantFuture,
            cohouseIDs: [cohouseId],
            isRevealed: true
        )
    }

    // MARK: - Visibility Computed Properties

    @Test("isRevealed returns false when no game")
    func isRevealed_noGame() {
        @Shared(.ckrGame) var ckrGame
        $ckrGame.withLock { $0 = nil }

        let state = PlanningFeature.State()
        #expect(state.isRevealed == false)
    }

    @Test("isRevealed returns false when game is not revealed")
    func isRevealed_notRevealed() {
        @Shared(.ckrGame) var ckrGame
        $ckrGame.withLock {
            $0 = CKRGame(
                startCKRCountdown: Date.distantPast,
                nextGameDate: Date.distantFuture,
                registrationDeadline: Date.distantFuture,
                isRevealed: false
            )
        }

        let state = PlanningFeature.State()
        #expect(state.isRevealed == false)
    }

    @Test("isRevealed returns true when game is revealed")
    func isRevealed_revealed() {
        let mockCohouse = Cohouse.mock
        @Shared(.ckrGame) var ckrGame
        $ckrGame.withLock { $0 = Self.makeRevealedGame(cohouseId: mockCohouse.id.uuidString) }

        let state = PlanningFeature.State()
        #expect(state.isRevealed == true)
    }

    @Test("isRegistered returns false when no cohouse")
    func isRegistered_noCohouse() {
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = nil }
        $ckrGame.withLock {
            $0 = CKRGame(
                startCKRCountdown: Date.distantPast,
                nextGameDate: Date.distantFuture,
                registrationDeadline: Date.distantFuture,
                isRevealed: true
            )
        }

        let state = PlanningFeature.State()
        #expect(state.isRegistered == false)
    }

    @Test("isRegistered returns false when cohouse not in game")
    func isRegistered_notRegistered() {
        let mockCohouse = Cohouse.mock
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock {
            $0 = CKRGame(
                startCKRCountdown: Date.distantPast,
                nextGameDate: Date.distantFuture,
                registrationDeadline: Date.distantFuture,
                cohouseIDs: ["other-id"],
                isRevealed: true
            )
        }

        let state = PlanningFeature.State()
        #expect(state.isRegistered == false)
    }

    @Test("isRegistered returns true when cohouse is in game")
    func isRegistered_registered() {
        let mockCohouse = Cohouse.mock
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = Self.makeRevealedGame(cohouseId: mockCohouse.id.uuidString) }

        let state = PlanningFeature.State()
        #expect(state.isRegistered == true)
    }

    // MARK: - onTask

    @Test("onTask loads planning successfully when revealed and registered")
    func onTask_success() async {
        let mockCohouse = Cohouse.mock
        let mockPlanning = Self.makeMockPlanning()

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = Self.makeRevealedGame(cohouseId: mockCohouse.id.uuidString) }

        let store = TestStore(initialState: PlanningFeature.State()) {
            PlanningFeature()
        } withDependencies: {
            $0.ckrClient.getMyPlanning = { _, _ in mockPlanning }
        }

        await store.send(.onTask) {
            $0.isLoading = true
        }

        await store.receive(\.planningLoaded) {
            $0.isLoading = false
            $0.planning = mockPlanning
            $0.errorMessage = nil
        }
    }

    @Test("onTask handles failure with error message")
    func onTask_failure() async {
        let mockCohouse = Cohouse.mock

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = Self.makeRevealedGame(cohouseId: mockCohouse.id.uuidString) }

        let store = TestStore(initialState: PlanningFeature.State()) {
            PlanningFeature()
        } withDependencies: {
            $0.ckrClient.getMyPlanning = { _, _ in
                throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
            }
        }

        await store.send(.onTask) {
            $0.isLoading = true
        }

        await store.receive(\.planningFailed) {
            $0.isLoading = false
            $0.errorMessage = "Network error"
        }
    }

    @Test("onTask does nothing when game is not revealed")
    func onTask_notRevealed() async {
        let mockCohouse = Cohouse.mock

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock {
            $0 = CKRGame(
                startCKRCountdown: Date.distantPast,
                nextGameDate: Date.distantFuture,
                registrationDeadline: Date.distantFuture,
                cohouseIDs: [mockCohouse.id.uuidString],
                isRevealed: false
            )
        }

        let store = TestStore(initialState: PlanningFeature.State()) {
            PlanningFeature()
        }

        // Should not trigger any effects
        await store.send(.onTask)
    }

    @Test("onTask does nothing when no game exists")
    func onTask_noGame() async {
        @Shared(.ckrGame) var ckrGame
        $ckrGame.withLock { $0 = nil }

        let store = TestStore(initialState: PlanningFeature.State()) {
            PlanningFeature()
        }

        await store.send(.onTask)
    }

    @Test("onTask does nothing when no cohouse exists")
    func onTask_noCohouse() async {
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = nil }
        $ckrGame.withLock {
            $0 = CKRGame(
                startCKRCountdown: Date.distantPast,
                nextGameDate: Date.distantFuture,
                registrationDeadline: Date.distantFuture,
                isRevealed: true
            )
        }

        let store = TestStore(initialState: PlanningFeature.State()) {
            PlanningFeature()
        }

        await store.send(.onTask)
    }

    // MARK: - planningLoaded

    @Test("planningLoaded sets planning and clears error")
    func planningLoaded() async {
        let mockPlanning = Self.makeMockPlanning()
        var initialState = PlanningFeature.State()
        initialState.isLoading = true
        initialState.errorMessage = "Previous error"

        let store = TestStore(initialState: initialState) {
            PlanningFeature()
        }

        await store.send(.planningLoaded(mockPlanning)) {
            $0.isLoading = false
            $0.planning = mockPlanning
            $0.errorMessage = nil
        }
    }

    // MARK: - planningFailed

    @Test("planningFailed sets error message and stops loading")
    func planningFailed() async {
        var initialState = PlanningFeature.State()
        initialState.isLoading = true

        let store = TestStore(initialState: initialState) {
            PlanningFeature()
        }

        await store.send(.planningFailed("Something went wrong")) {
            $0.isLoading = false
            $0.errorMessage = "Something went wrong"
        }
    }
}
