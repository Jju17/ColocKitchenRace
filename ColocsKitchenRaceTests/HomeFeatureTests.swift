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

    @Test("BUG: openRegisterLink discards result and doesn't handle errors")
    func openRegisterLink_discardsResult() async {
        var registerCalled = false

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.registerCohouse = { _ in
                registerCalled = true
                return .success(true)
            }
        }

        // Set a cohouse via shared state so the guard passes
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        await store.send(.openRegisterLink)

        // BUG: registerCohouse is called but result is discarded with `let _ = ...`
        // No error handling, no success feedback
        #expect(registerCalled == true)
    }

    @Test("openRegisterLink does nothing when cohouse is nil")
    func openRegisterLink_withoutCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        // Guard should prevent calling registerCohouse
        await store.send(.openRegisterLink)
    }

    // MARK: - Delegate

    @Test("switchToCohouseButtonTapped delegate is forwarded correctly")
    func switchToCohouse() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.delegate(.switchToCohouseButtonTapped))
    }

    // MARK: - BUG: registerCohouse is called synchronously, not in .run

    @Test("BUG: registerCohouse called outside .run effect - blocks reducer")
    func registerCohouse_calledSynchronously() async {
        // The registerCohouse call in HomeFeature is:
        //   let _ = self.ckrClient.registerCohouse(cohouse: cohouse)
        //   return .none
        //
        // This is NOT wrapped in .run { }, so:
        // 1. If registerCohouse were async, it would not await
        // 2. If it throws, the error is unhandled
        // 3. The result is discarded

        // Currently registerCohouse is sync (returns .success(true)),
        // but this pattern is fragile. If the implementation changes
        // to be async/throwing, this will silently break.
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.ckrClient.registerCohouse = { _ in .success(true) }
        }

        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        await store.send(.openRegisterLink)
    }
}
