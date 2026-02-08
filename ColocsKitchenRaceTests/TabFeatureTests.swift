//
//  TabFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing

@testable import ColocsKitchenRace

@MainActor
struct TabFeatureTests {

    // MARK: - Tab Selection

    @Test("Changing tab updates selectedTab")
    func tabChanged() async {
        let store = TestStore(initialState: TabFeature.State()) {
            TabFeature()
        }

        await store.send(.tabChanged(.challenges)) {
            $0.selectedTab = .challenges
        }

        await store.send(.tabChanged(.cohouse)) {
            $0.selectedTab = .cohouse
        }

        await store.send(.tabChanged(.home)) {
            $0.selectedTab = .home
        }
    }

    // MARK: - Delegate Routing

    @Test("Home delegate switchToCohouseButtonTapped switches tab to cohouse")
    func homeDelegateSwitchesToCohouse() async {
        let store = TestStore(initialState: TabFeature.State()) {
            TabFeature()
        }

        #expect(store.state.selectedTab == .home)

        await store.send(.home(.delegate(.switchToCohouseButtonTapped))) {
            $0.selectedTab = .cohouse
        }
    }

    @Test("Challenge delegate switchToCohouseButtonTapped switches tab to cohouse")
    func challengeDelegateSwitchesToCohouse() async {
        let store = TestStore(initialState: TabFeature.State(selectedTab: .challenges)) {
            TabFeature()
        }

        await store.send(.challenge(.delegate(.switchToCohouseButtonTapped))) {
            $0.selectedTab = .cohouse
        }
    }

    // MARK: - Default State

    @Test("Default tab is home")
    func defaultTab() {
        let state = TabFeature.State()
        #expect(state.selectedTab == .home)
    }
}
