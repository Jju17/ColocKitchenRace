//
//  JoinEditionFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 22/03/2026.
//

import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import ColocsKitchenRace

@MainActor
struct JoinEditionFeatureTests {

    // MARK: - Join by Code

    @Test("joinButtonTapped with empty code shows error")
    func joinButtonTapped_emptyCode() async {
        let store = TestStore(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        }

        await store.send(.joinButtonTapped) {
            $0.errorMessage = "Enter a code to join"
        }
    }

    @Test("joinButtonTapped with whitespace-only code shows error")
    func joinButtonTapped_whitespaceCode() async {
        var state = JoinEditionFeature.State()
        state.joinCode = "   "

        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        }

        await store.send(.joinButtonTapped) {
            $0.errorMessage = "Enter a code to join"
        }
    }

    @Test("joinButtonTapped with valid code calls editionClient and updates state")
    func joinButtonTapped_validCode() async {
        var state = JoinEditionFeature.State()
        state.joinCode = "ABC123"

        let response = JoinEditionResponse(
            gameId: "game-special-1",
            title: "La CKR de Julien",
            editionType: "special"
        )

        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.joinByCode = { _ in response }
            $0.editionClient.getEdition = { _ in nil }
        }
        store.exhaustivity = .off

        await store.send(.joinButtonTapped) {
            $0.isJoining = true
            $0.errorMessage = nil
            $0.successMessage = nil
        }

        // After join succeeds: code cleared, success message set
        await store.skipReceivedActions()
        #expect(store.state.isJoining == false)
        #expect(store.state.joinCode == "")
        #expect(store.state.successMessage == "Joined \"La CKR de Julien\"!")
    }

    @Test("joinButtonTapped with error shows error message")
    func joinButtonTapped_error() async {
        var state = JoinEditionFeature.State()
        state.joinCode = "BADCOD"

        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.joinByCode = { _ in
                throw EditionClientError.notFound
            }
        }
        store.exhaustivity = .off

        await store.send(.joinButtonTapped) {
            $0.isJoining = true
        }

        await store.skipReceivedActions()
        #expect(store.state.isJoining == false)
        #expect(store.state.errorMessage == EditionClientError.notFound.localizedDescription)
    }

    @Test("joining uppercases code before sending")
    func joinButtonTapped_uppercasesCode() async {
        var state = JoinEditionFeature.State()
        state.joinCode = "abc123"

        var capturedCode: String?
        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.joinByCode = { code in
                capturedCode = code
                return JoinEditionResponse(gameId: "g1", title: "T", editionType: "special")
            }
            $0.editionClient.getEdition = { _ in nil }
        }
        store.exhaustivity = .off

        await store.send(.joinButtonTapped)
        await store.skipReceivedActions()
        #expect(capturedCode == "ABC123")
    }

    // MARK: - Leave Edition

    @Test("leaveButtonTapped calls editionClient.leave and clears state")
    func leaveButtonTapped_success() async {
        let mockUser = User(id: UUID(), activeEditionId: "game-special-1")

        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = mockUser }

        var leaveCalled = false
        let store = TestStore(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.leave = { gameId in
                #expect(gameId == "game-special-1")
                leaveCalled = true
            }
        }
        store.exhaustivity = .off

        await store.send(.leaveButtonTapped) {
            $0.isLeaving = true
            $0.errorMessage = nil
        }

        await store.skipReceivedActions()
        #expect(leaveCalled)
        #expect(store.state.isLeaving == false)
        #expect(store.state.activeEdition == nil)
    }

    @Test("leaveButtonTapped without activeEditionId does nothing")
    func leaveButtonTapped_noActiveEdition() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = User(id: UUID()) }

        let store = TestStore(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        }

        await store.send(.leaveButtonTapped)
    }

    @Test("leaveButtonTapped with server error shows error message")
    func leaveButtonTapped_error() async {
        let mockUser = User(id: UUID(), activeEditionId: "game-1")

        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = mockUser }

        let store = TestStore(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.leave = { _ in
                throw EditionClientError.registeredCannotLeave
            }
        }
        store.exhaustivity = .off

        await store.send(.leaveButtonTapped) {
            $0.isLeaving = true
        }

        await store.skipReceivedActions()
        #expect(store.state.isLeaving == false)
        #expect(store.state.errorMessage == EditionClientError.registeredCannotLeave.localizedDescription)
    }

    // MARK: - Load Active Edition

    @Test("loadActiveEdition fetches and stores game")
    func loadActiveEdition_success() async {
        let gameId = "game-special-1"
        let mockUser = User(id: UUID(), activeEditionId: gameId)
        let mockGame = CKRGame(
            startCKRCountdown: Date(),
            nextGameDate: Date(),
            registrationDeadline: Date(),
            editionType: .special,
            title: "Special CKR",
            joinCode: "ABC123"
        )

        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = mockUser }

        let store = TestStore(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        } withDependencies: {
            $0.editionClient.getEdition = { id in
                #expect(id == gameId)
                return mockGame
            }
        }
        store.exhaustivity = .off

        await store.send(.loadActiveEdition)
        await store.skipReceivedActions()

        #expect(store.state.activeEdition == mockGame)
        #expect(store.state.isLoadingEdition == false)
    }

    @Test("loadActiveEdition without activeEditionId clears edition")
    func loadActiveEdition_noActiveEdition() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = User(id: UUID()) }

        var state = JoinEditionFeature.State()
        state.activeEdition = CKRGame(
            startCKRCountdown: Date(),
            nextGameDate: Date(),
            registrationDeadline: Date()
        )

        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        }

        await store.send(.loadActiveEdition) {
            $0.activeEdition = nil
        }
    }

    // MARK: - Binding clears errors

    @Test("typing in joinCode clears error and success messages")
    func binding_clearsMessages() async {
        var state = JoinEditionFeature.State()
        state.errorMessage = "Some error"
        state.successMessage = "Some success"

        let store = TestStore(initialState: state) {
            JoinEditionFeature()
        }

        await store.send(.binding(.set(\.joinCode, "X"))) {
            $0.joinCode = "X"
            $0.errorMessage = nil
            $0.successMessage = nil
        }
    }

    // MARK: - Computed Properties

    @Test("hasActiveEdition reflects userInfo.activeEditionId")
    func hasActiveEdition_computed() {
        @Shared(.userInfo) var userInfo

        $userInfo.withLock { $0 = User(id: UUID(), activeEditionId: "game-1") }
        let stateWithEdition = JoinEditionFeature.State()
        #expect(stateWithEdition.hasActiveEdition == true)

        $userInfo.withLock { $0 = User(id: UUID()) }
        let stateWithout = JoinEditionFeature.State()
        #expect(stateWithout.hasActiveEdition == false)
    }
}
