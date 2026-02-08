//
//  UserProfileDetailFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing

@testable import ColocsKitchenRace
import Foundation

@MainActor
struct UserProfileDetailFeatureTests {

    // MARK: - Edit Flow

    @Test("editUserButtonTapped opens edit sheet")
    func editUserButtonTapped() async {
        let store = TestStore(initialState: UserProfileDetailFeature.State()) {
            UserProfileDetailFeature()
        }

        await store.send(.editUserButtonTapped) {
            $0.destination = .editUser(UserProfileFormFeature.State())
        }
    }

    @Test("confirmEditUserButtonTapped saves user and dismisses")
    func confirmEdit() async {
        var updatedUser: User?
        let mockUser = User.mockUser

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: mockUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authentificationClient.updateUser = { user in
                updatedUser = user
            }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }

        #expect(updatedUser == mockUser)
    }

    @Test("confirmEditUserButtonTapped does nothing when destination is nil")
    func confirmEdit_noDestination() async {
        let store = TestStore(initialState: UserProfileDetailFeature.State()) {
            UserProfileDetailFeature()
        }

        await store.send(.confirmEditUserButtonTapped)
    }

    @Test("BUG: confirmEditUserButtonTapped has no error handling for updateUser failure")
    func confirmEdit_errorNotHandled() async {
        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: .mockUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authentificationClient.updateUser = { _ in
                throw NSError(domain: "firebase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }
        // BUG: Error is thrown in .run but not caught
        // User thinks save was successful but it wasn't
        // Destination is already dismissed so edits are lost
    }

    // MARK: - Dismiss

    @Test("Dismiss clears destination")
    func dismissDestination() async {
        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State())
            )
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.dismissDestinationButtonTapped) {
            $0.destination = nil
        }
    }

    // MARK: - Sign Out

    @Test("signOutButtonTapped calls signOut")
    func signOut() async {
        var signOutCalled = false

        let store = TestStore(initialState: UserProfileDetailFeature.State()) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authentificationClient.signOut = {
                signOutCalled = true
            }
        }

        await store.send(.signOutButtonTapped)

        #expect(signOutCalled == true)
    }

    @Test("BUG: signOut error is silently caught - user gets no feedback")
    func signOut_error() async {
        let store = TestStore(initialState: UserProfileDetailFeature.State()) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authentificationClient.signOut = {
                throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign out failed"])
            }
        }

        // BUG: Error is caught and logged but user sees no error message
        // The Logger message says "Already logged out" which is misleading
        await store.send(.signOutButtonTapped)
    }
}
