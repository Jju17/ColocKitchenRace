//
//  UserProfileFormFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing

@testable import ColocsKitchenRace

@MainActor
struct UserProfileFormFeatureTests {

    // MARK: - onAppear

    @Test("onAppearTriggered refreshes wipUser from shared user info")
    func onAppearTriggered() async {
        @Shared(.userInfo) var userInfo
        let mockUser = User.mockUser
        $userInfo.withLock { $0 = mockUser }

        // State() init already sets wipUser from shared, so onAppear is a no-op
        let store = TestStore(initialState: UserProfileFormFeature.State()) {
            UserProfileFormFeature()
        }

        await store.send(.onAppearTriggered)
    }

    @Test("onAppearTriggered updates wipUser when shared changed after init")
    func onAppearTriggered_updatesAfterChange() async {
        @Shared(.userInfo) var userInfo
        let mockUser = User.mockUser
        $userInfo.withLock { $0 = mockUser }

        // Start with a stale wipUser to simulate reopening the form
        var staleUser = User.mockUser
        staleUser.firstName = "OldName"
        let store = TestStore(initialState: UserProfileFormFeature.State(wipUser: staleUser)) {
            UserProfileFormFeature()
        }

        await store.send(.onAppearTriggered) {
            $0.wipUser = mockUser
        }
    }

    @Test("onAppearTriggered does nothing when userInfo is nil")
    func onAppearTriggered_nilUser() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }

        let store = TestStore(initialState: UserProfileFormFeature.State()) {
            UserProfileFormFeature()
        }

        await store.send(.onAppearTriggered)
        // wipUser stays as emptyUser
    }

    // MARK: - Dietary Preferences Binding

    @Test("Dietary preferences can be toggled via binding")
    func dietaryPreferencesToggle() async {
        let store = TestStore(initialState: UserProfileFormFeature.State(wipUser: .mockUser)) {
            UserProfileFormFeature()
        }

        // Add preferences by updating the whole wipUser
        var updatedUser1 = User.mockUser
        updatedUser1.dietaryPreferences = [.lactoseFree, .vegan]
        await store.send(\.binding.wipUser, updatedUser1) {
            $0.wipUser = updatedUser1
        }

        // Remove a preference
        var updatedUser2 = updatedUser1
        updatedUser2.dietaryPreferences = [.vegan]
        await store.send(\.binding.wipUser, updatedUser2) {
            $0.wipUser = updatedUser2
        }
    }

    // MARK: - Name binding

    @Test("First and last name can be updated via binding")
    func nameBinding() async {
        let store = TestStore(initialState: UserProfileFormFeature.State(wipUser: .mockUser)) {
            UserProfileFormFeature()
        }

        var updatedUser1 = User.mockUser
        updatedUser1.firstName = "Jean"
        await store.send(\.binding.wipUser, updatedUser1) {
            $0.wipUser = updatedUser1
        }

        var updatedUser2 = updatedUser1
        updatedUser2.lastName = "Dupont"
        await store.send(\.binding.wipUser, updatedUser2) {
            $0.wipUser = updatedUser2
        }
    }

    // MARK: - News subscription toggle

    @Test("News subscription toggle updates state")
    func newsToggle() async {
        var user = User.mockUser
        user.isSubscribeToNews = false

        let store = TestStore(initialState: UserProfileFormFeature.State(wipUser: user)) {
            UserProfileFormFeature()
        }

        var updatedUser = user
        updatedUser.isSubscribeToNews = true
        await store.send(\.binding.wipUser, updatedUser) {
            $0.wipUser = updatedUser
        }
    }

    // MARK: - wipUser initialization

    @Test("State initializes wipUser from shared userInfo when available")
    func wipUserInitFromShared() {
        @Shared(.userInfo) var userInfo
        let mockUser = User.mockUser
        $userInfo.withLock { $0 = mockUser }

        let state = UserProfileFormFeature.State()
        #expect(state.wipUser == mockUser)
    }

    @Test("State initializes wipUser as emptyUser when userInfo is nil")
    func wipUserInitEmpty() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }

        let state = UserProfileFormFeature.State()
        #expect(state.wipUser.firstName == "")
        #expect(state.wipUser.lastName == "")
    }
}
