//
//  HomeFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import ColocsKitchenRace

@MainActor
struct HomeFeatureTests {

    // MARK: - Registration Form

    @Test("openRegisterForm presents form when conditions are met")
    func openRegisterForm() async {
        let mockCohouse = Cohouse.mock
        let mockGame = CKRGame(
            startCKRCountdown: Date.distantPast,
            nextGameDate: Date.distantFuture,
            registrationDeadline: Date.distantFuture,
            participantsID: []
        )

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = mockGame }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.openRegisterForm) {
            $0.registrationForm = CKRRegistrationFormFeature.State(
                cohouse: mockCohouse,
                gameId: mockGame.id.uuidString,
                pricePerPersonCents: mockGame.pricePerPersonCents,
                cohouseType: .mixed
            )
        }
    }

    @Test("openRegisterForm does nothing when cohouse is nil")
    func openRegisterForm_withoutCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        await store.send(.openRegisterForm)
    }

    @Test("openRegisterForm does nothing when already registered")
    func openRegisterForm_alreadyRegistered() async {
        let mockCohouse = Cohouse.mock
        let mockGame = CKRGame(
            startCKRCountdown: Date.distantPast,
            nextGameDate: Date.distantFuture,
            registrationDeadline: Date.distantFuture,
            participantsID: [mockCohouse.id.uuidString]
        )

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = mockGame }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.openRegisterForm)
    }

    @Test("registration success dismisses form and refreshes")
    func registrationSuccess() async {
        let mockCohouse = Cohouse.mock
        let mockGame = CKRGame(
            startCKRCountdown: Date.distantPast,
            nextGameDate: Date.distantFuture,
            registrationDeadline: Date.distantFuture,
            participantsID: []
        )

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = mockGame }

        var initialState = HomeFeature.State()
        initialState.registrationForm = CKRRegistrationFormFeature.State(
            cohouse: mockCohouse,
            gameId: mockGame.id.uuidString,
            pricePerPersonCents: mockGame.pricePerPersonCents
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.getLast = { .success(nil) }
            $0.newsClient.getLast = { .success([]) }
        }

        await store.send(.registrationForm(.presented(.delegate(.registrationSucceeded)))) {
            $0.registrationForm = nil
        }

        await store.receive(\.refresh)
        await store.receive(\.coverImageLoaded)
    }

    // MARK: - Refresh

    @Test("refresh re-fetches CKR game, news, and cover image")
    func refresh() async {
        var ckrCalled = false
        var newsCalled = false

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.getLast = {
                ckrCalled = true
                return .success(nil)
            }
            $0.newsClient.getLast = {
                newsCalled = true
                return .success([])
            }
        }

        await store.send(.refresh)
        await store.receive(\.coverImageLoaded)

        #expect(ckrCalled)
        #expect(newsCalled)
    }

    @Test("refresh loads cover image when cohouse has coverImagePath")
    func refresh_loadsCoverImage() async {
        let fakeImageData = Data([0xFF, 0xD8, 0xFF])
        var cohouse = Cohouse.mock
        cohouse.coverImagePath = "cohouses/test/cover_image.jpg"

        @Shared(.cohouse) var sharedCohouse
        $sharedCohouse.withLock { $0 = cohouse }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.getLast = { .success(nil) }
            $0.newsClient.getLast = { .success([]) }
            $0.cohouseClient.loadCoverImage = { _ in fakeImageData }
        }

        await store.send(.refresh)
        await store.receive(\.coverImageLoaded) {
            $0.coverImageData = fakeImageData
        }
    }

    // MARK: - Edge Cases

    @Test("openRegisterForm does nothing when ckrGame is nil")
    func openRegisterForm_noGame() async {
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = .mock }
        $ckrGame.withLock { $0 = nil }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.openRegisterForm)
    }

    @Test("openRegisterForm does nothing when registration deadline passed")
    func openRegisterForm_registrationClosed() async {
        let mockCohouse = Cohouse.mock
        let mockGame = CKRGame(
            startCKRCountdown: Date.distantPast,
            nextGameDate: Date.distantFuture,
            registrationDeadline: Date.distantPast,
            participantsID: []
        )

        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        $cohouse.withLock { $0 = mockCohouse }
        $ckrGame.withLock { $0 = mockGame }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.openRegisterForm)
    }

    @Test("refresh with cover image load failure sends nil data")
    func refresh_coverImageLoadFailure() async {
        var cohouse = Cohouse.mock
        cohouse.coverImagePath = "cohouses/test/cover_image.jpg"

        @Shared(.cohouse) var sharedCohouse
        $sharedCohouse.withLock { $0 = cohouse }

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.getLast = { .success(nil) }
            $0.newsClient.getLast = { .success([]) }
            $0.cohouseClient.loadCoverImage = { _ in
                throw CKRError.firebaseError("Storage unavailable")
            }
        }

        await store.send(.refresh)
        await store.receive(\.coverImageLoaded)
    }

    @Test("coverImageLoaded with nil clears existing data")
    func coverImageLoaded_nil_clearsData() async {
        var initialState = HomeFeature.State()
        initialState.coverImageData = Data([0xFF, 0xD8, 0xFF])

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        }

        await store.send(.coverImageLoaded(nil)) {
            $0.coverImageData = nil
        }
    }

    // MARK: - Delegate

    @Test("switchToCohouseButtonTapped delegate is forwarded correctly")
    func switchToCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.delegate(.switchToCohouseButtonTapped))
    }
}
