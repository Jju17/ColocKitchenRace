//
//  HomeFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing

@testable import ColocsKitchenRace

@MainActor
struct HomeFeatureTests {

    // MARK: - Register Link

    @Test("openRegisterLink calls registerCohouse in a .run effect")
    func openRegisterLink() async {
        var registerCalled = false

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.registerCohouse = { _ in
                registerCalled = true
                return .success(true)
            }
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        await store.send(.openRegisterLink)

        #expect(registerCalled == true)
    }

    @Test("openRegisterLink does nothing when cohouse is nil")
    func openRegisterLink_withoutCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        await store.send(.openRegisterLink)
    }

    @Test("openRegisterLink handles failure gracefully")
    func openRegisterLink_failure() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.registerCohouse = { _ in .failure(.firebaseError("Network unavailable")) }
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        // Error is logged, no crash
        await store.send(.openRegisterLink)
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

    // MARK: - Delegate

    @Test("switchToCohouseButtonTapped delegate is forwarded correctly")
    func switchToCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.delegate(.switchToCohouseButtonTapped))
    }
}
