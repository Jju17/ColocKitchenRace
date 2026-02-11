//
//  CohouseFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 11/02/2026.
//

import ComposableArchitecture
import Sharing
import Testing

@testable import ColocsKitchenRace

@MainActor
struct CohouseFeatureTests {

    // MARK: - cohouseChanged

    @Test("cohouseChanged with cohouse creates detail state")
    func cohouseChanged_withCohouse_createsDetail() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: CohouseFeature.State()) {
            CohouseFeature()
        }
        store.exhaustivity = .off

        #expect(store.state.cohouseDetail == nil)

        await store.send(.cohouseChanged)

        #expect(store.state.cohouseDetail != nil)
    }

    @Test("cohouseChanged with nil cohouse keeps detail nil")
    func cohouseChanged_withNilCohouse_clearsDetail() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = nil }

        let store = TestStore(initialState: CohouseFeature.State()) {
            CohouseFeature()
        }

        // cohouseDetail is already nil, so no state change
        await store.send(.cohouseChanged)

        #expect(store.state.cohouseDetail == nil)
    }

    @Test("cohouseChanged does not recreate detail when it already exists")
    func cohouseChanged_existingDetail_doesNotRecreate() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: CohouseFeature.State()) {
            CohouseFeature()
        }
        store.exhaustivity = .off

        // First call creates the detail
        await store.send(.cohouseChanged)
        let firstDetail = store.state.cohouseDetail
        #expect(firstDetail != nil)

        // Second call should NOT recreate — same object
        await store.send(.cohouseChanged)
        #expect(store.state.cohouseDetail == firstDetail)
    }

    @Test("cohouseChanged clears detail when cohouse removed")
    func cohouseChanged_transitionFromDetailToNil() async {
        @Shared(.cohouse) var cohouse
        $cohouse.withLock { $0 = .mock }

        let store = TestStore(initialState: CohouseFeature.State()) {
            CohouseFeature()
        }
        store.exhaustivity = .off

        // Create detail
        await store.send(.cohouseChanged)
        #expect(store.state.cohouseDetail != nil)

        // Remove cohouse
        $cohouse.withLock { $0 = nil }

        await store.send(.cohouseChanged)
        #expect(store.state.cohouseDetail == nil)
    }

    // MARK: - Child actions

    @Test("noCohouse action does not change parent state")
    func noCohouse_passThrough() async {
        let store = TestStore(initialState: CohouseFeature.State()) {
            CohouseFeature()
        }

        // Send a noCohouse action — parent state should not change
        await store.send(.noCohouse(.createCohouseButtonTapped))
    }
}
