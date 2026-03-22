//
//  EditionFilteringTests.swift
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
struct EditionFilteringTests {

    // MARK: - Helpers

    private func makeChallenge(
        id: UUID = UUID(),
        editionId: String? = nil
    ) -> Challenge {
        Challenge(
            id: id,
            title: "Challenge \(id.uuidString.prefix(4))",
            startDate: Date.from(year: 2024, month: 1, day: 1, hour: 0),
            endDate: Date.from(year: 2026, month: 12, day: 31, hour: 23),
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            editionId: editionId
        )
    }

    // MARK: - Global Mode (no activeEditionId)

    @Test("In global mode, only challenges without editionId are shown")
    func globalMode_filtersOutSpecialChallenges() async {
        let mockCohouse = Cohouse.mock
        let globalChallenge = makeChallenge()
        let specialChallenge = makeChallenge(editionId: "special-game-1")

        @Shared(.cohouse) var cohouse
        @Shared(.userInfo) var userInfo
        $cohouse.withLock { $0 = mockCohouse }
        $userInfo.withLock { $0 = User(id: UUID()) } // No activeEditionId

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [globalChallenge, specialChallenge] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([]) }
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
                    id: globalChallenge.id,
                    challenge: globalChallenge,
                    cohouseId: mockCohouse.id.uuidString,
                    cohouseName: mockCohouse.name,
                    response: nil,
                    liveStatus: nil
                )
            ])
        }
    }

    // MARK: - Special Edition Mode

    @Test("In special edition mode, only that edition's challenges are shown")
    func specialEditionMode_filtersToEdition() async {
        let editionId = "special-game-1"
        let mockCohouse = Cohouse.mock
        let globalChallenge = makeChallenge()
        let myEditionChallenge = makeChallenge(editionId: editionId)
        let otherEditionChallenge = makeChallenge(editionId: "other-game-2")

        @Shared(.cohouse) var cohouse
        @Shared(.userInfo) var userInfo
        $cohouse.withLock { $0 = mockCohouse }
        $userInfo.withLock { $0 = User(id: UUID(), activeEditionId: editionId) }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [globalChallenge, myEditionChallenge, otherEditionChallenge] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([]) }
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
                    id: myEditionChallenge.id,
                    challenge: myEditionChallenge,
                    cohouseId: mockCohouse.id.uuidString,
                    cohouseName: mockCohouse.name,
                    response: nil,
                    liveStatus: nil
                )
            ])
        }
    }

    // MARK: - No challenges for edition

    @Test("Special edition with no matching challenges shows empty tiles")
    func specialEditionMode_noMatchingChallenges() async {
        let mockCohouse = Cohouse.mock
        let globalChallenge = makeChallenge()
        let otherEditionChallenge = makeChallenge(editionId: "other-game")

        @Shared(.cohouse) var cohouse
        @Shared(.userInfo) var userInfo
        $cohouse.withLock { $0 = mockCohouse }
        $userInfo.withLock { $0 = User(id: UUID(), activeEditionId: "my-edition-no-challenges") }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [globalChallenge, otherEditionChallenge] }
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
    }

    // MARK: - Responses matched correctly with edition filtering

    @Test("Responses are matched to filtered challenges")
    func responsesMatchedWithFiltering() async {
        let editionId = "special-game-1"
        let mockCohouse = Cohouse.mock
        let myChallenge = makeChallenge(editionId: editionId)
        let globalChallenge = makeChallenge()

        let myResponse = ChallengeResponse(
            id: UUID(),
            challengeId: myChallenge.id,
            cohouseId: mockCohouse.id.uuidString,
            challengeTitle: myChallenge.title,
            cohouseName: mockCohouse.name,
            content: .noChoice,
            status: .waiting,
            submissionDate: Date()
        )

        let globalResponse = ChallengeResponse(
            id: UUID(),
            challengeId: globalChallenge.id,
            cohouseId: mockCohouse.id.uuidString,
            challengeTitle: globalChallenge.title,
            cohouseName: mockCohouse.name,
            content: .noChoice,
            status: .validated,
            submissionDate: Date()
        )

        @Shared(.cohouse) var cohouse
        @Shared(.userInfo) var userInfo
        $cohouse.withLock { $0 = mockCohouse }
        $userInfo.withLock { $0 = User(id: UUID(), activeEditionId: editionId) }

        let store = TestStore(initialState: ChallengeFeature.State()) {
            ChallengeFeature()
        } withDependencies: {
            $0.challengesClient.getAll = { [myChallenge, globalChallenge] }
            $0.challengeResponseClient.getAllForCohouse = { _ in .success([myResponse, globalResponse]) }
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
                    id: myChallenge.id,
                    challenge: myChallenge,
                    cohouseId: mockCohouse.id.uuidString,
                    cohouseName: mockCohouse.name,
                    response: myResponse,
                    liveStatus: myResponse.status
                )
            ])
        }
    }

    // MARK: - Model Tests

    @Test("Challenge editionId defaults to nil")
    func challengeEditionId_defaultsNil() {
        let challenge = Challenge(
            id: UUID(),
            title: "Test",
            startDate: Date(),
            endDate: Date(),
            body: "Body",
            content: .noChoice(NoChoiceContent())
        )
        #expect(challenge.editionId == nil)
    }

    @Test("Challenge editionId can be set")
    func challengeEditionId_canBeSet() {
        let challenge = Challenge(
            id: UUID(),
            title: "Test",
            startDate: Date(),
            endDate: Date(),
            body: "Body",
            content: .noChoice(NoChoiceContent()),
            editionId: "game-special-1"
        )
        #expect(challenge.editionId == "game-special-1")
    }

    @Test("CKRGame editionType defaults to .global")
    func ckrGameEditionType_defaultsGlobal() {
        let game = CKRGame(
            startCKRCountdown: Date(),
            nextGameDate: Date(),
            registrationDeadline: Date()
        )
        #expect(game.editionType == .global)
        #expect(game.status == .published)
    }

    @Test("CKRGame special edition fields")
    func ckrGameSpecialEdition() {
        let game = CKRGame(
            startCKRCountdown: Date(),
            nextGameDate: Date(),
            registrationDeadline: Date(),
            editionType: .special,
            title: "CKR de Julien",
            joinCode: "ABC123",
            createdByAuthUid: "auth-uid-1",
            status: .draft
        )
        #expect(game.editionType == .special)
        #expect(game.title == "CKR de Julien")
        #expect(game.joinCode == "ABC123")
        #expect(game.status == .draft)
    }

    @Test("User activeEditionId defaults to nil")
    func userActiveEditionId_defaultsNil() {
        let user = User(id: UUID())
        #expect(user.activeEditionId == nil)
    }

    @Test("User activeEditionId can be set")
    func userActiveEditionId_canBeSet() {
        let user = User(id: UUID(), activeEditionId: "game-1")
        #expect(user.activeEditionId == "game-1")
    }
}
