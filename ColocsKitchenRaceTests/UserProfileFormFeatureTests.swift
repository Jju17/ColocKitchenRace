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

    @Test("onAppearTriggered copies shared user info to wipUser")
    func onAppearTriggered() async {
        @Shared(.userInfo) var userInfo
        let mockUser = User.mockUser
        $userInfo.withLock { $0 = mockUser }

        let store = TestStore(initialState: UserProfileFormFeature.State()) {
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

    // MARK: - Sign Out (duplicate action in form)

    @Test("BUG: signOutButtonTapped exists both in UserProfileDetailFeature AND UserProfileFormFeature")
    func signOut_duplicateInForm() async {
        var signOutCalled = false

        let store = TestStore(initialState: UserProfileFormFeature.State()) {
            UserProfileFormFeature()
        } withDependencies: {
            $0.authenticationClient.signOut = {
                signOutCalled = true
            }
        }

        // BUG: SignOut is callable from the form view while editing
        // This means you can sign out while in the middle of editing your profile
        // The edit sheet will dismiss due to auth state change, but the UX is confusing
        await store.send(.signOutButtonTapped)
        #expect(signOutCalled == true)
    }

    // MARK: - BUG: wipUser starts as emptyUser before onAppear

    @Test("BUG: Before onAppear, wipUser is empty - form briefly shows empty fields")
    func wipUserStartsEmpty() {
        let state = UserProfileFormFeature.State()

        // BUG: wipUser is initialized as .emptyUser
        // If the view renders before onAppear fires, it shows empty fields momentarily
        #expect(state.wipUser.firstName == "")
        #expect(state.wipUser.lastName == "")
    }
}
