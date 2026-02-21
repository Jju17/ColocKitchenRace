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
        store.exhaustivity = .off

        await store.send(.editUserButtonTapped) {
            // wipUser uses UUID() so we can't predict the exact state
            // Just verify destination is set to editUser
            guard case .editUser = $0.destination else {
                Issue.record("Expected destination to be .editUser")
                return
            }
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
            $0.authenticationClient.updateUser = { user in
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

    @Test("confirmEditUserButtonTapped handles updateUser failure gracefully")
    func confirmEdit_errorHandled() async {
        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: .mockUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in
                throw NSError(domain: "firebase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }
        // Error is caught and logged, no crash
    }

    // MARK: - Edit Validation

    @Test("confirmEdit with empty firstName shows error and keeps sheet open")
    func confirmEdit_emptyFirstName() async {
        var invalidUser = User.mockUser
        invalidUser.firstName = ""

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: invalidUser))
            )
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }
    }

    @Test("confirmEdit with empty lastName shows error and keeps sheet open")
    func confirmEdit_emptyLastName() async {
        var invalidUser = User.mockUser
        invalidUser.lastName = ""

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: invalidUser))
            )
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }
    }

    @Test("confirmEdit with whitespace-only fields shows error")
    func confirmEdit_whitespaceOnly() async {
        var invalidUser = User.mockUser
        invalidUser.firstName = "   "
        invalidUser.lastName = "  "

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: invalidUser))
            )
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }
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
            $0.authenticationClient.signOut = {
                signOutCalled = true
            }
        }

        await store.send(.signOutButtonTapped)

        #expect(signOutCalled == true)
    }

    @Test("signOut error shows feedback to user")
    func signOut_errorShowsFeedback() async {
        let store = TestStore(initialState: UserProfileDetailFeature.State()) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.signOut = {
                throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign out failed"])
            }
        }

        await store.send(.signOutButtonTapped)

        await store.receive(\.signOutFailed) {
            $0.errorMessage = "Sign out failed. Please try again."
        }
    }

    @Test("dismissErrorMessageButtonTapped clears error")
    func dismissError() async {
        let store = TestStore(
            initialState: UserProfileDetailFeature.State(errorMessage: "Some error")
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.dismissErrorMessageButtonTapped) {
            $0.errorMessage = nil
        }
    }

    @Test("dismissSuccessMessageButtonTapped clears successMessage")
    func dismissSuccess() async {
        let store = TestStore(
            initialState: UserProfileDetailFeature.State(successMessage: "Some success")
        ) {
            UserProfileDetailFeature()
        }

        await store.send(.dismissSuccessMessageButtonTapped) {
            $0.successMessage = nil
        }
    }

    // MARK: - Email Change with Verification

    @Test("confirmEdit with changed email sends verification and saves other fields")
    func confirmEdit_emailChanged_sendsVerification() async {
        @Shared(.userInfo) var userInfo
        var originalUser = User.mockUser
        originalUser.email = "old@test.com"
        $userInfo.withLock { $0 = originalUser }

        var changedUser = originalUser
        changedUser.email = "new@test.com"
        changedUser.firstName = "UpdatedName"

        var updatedUser: User?
        var verificationEmail: String?

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: changedUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { user in updatedUser = user }
            $0.authenticationClient.sendVerificationEmail = { email in verificationEmail = email }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }

        await store.receive(\._emailVerificationSent) {
            $0.successMessage = "A verification link has been sent to new@test.com. Your email will be updated once you click it."
        }

        // Other fields saved with the OLD email
        #expect(updatedUser?.email == "old@test.com")
        #expect(updatedUser?.firstName == "UpdatedName")
        // Verification sent to NEW email
        #expect(verificationEmail == "new@test.com")

        $userInfo.withLock { $0 = nil }
    }

    @Test("confirmEdit with changed email but sendVerification fails shows error")
    func confirmEdit_emailChanged_verificationFails() async {
        @Shared(.userInfo) var userInfo
        var originalUser = User.mockUser
        originalUser.email = "old@test.com"
        $userInfo.withLock { $0 = originalUser }

        var changedUser = originalUser
        changedUser.email = "new@test.com"

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: changedUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in }
            $0.authenticationClient.sendVerificationEmail = { _ in
                throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Too many requests"])
            }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }

        await store.receive(\._emailChangeFailed) {
            $0.errorMessage = "Too many requests"
        }

        $userInfo.withLock { $0 = nil }
    }

    @Test("confirmEdit with same email does not send verification")
    func confirmEdit_sameEmail_noVerification() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        var sameEmailUser = User.mockUser
        sameEmailUser.firstName = "NewName"

        var updatedUser: User?
        var verificationCalled = false

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: sameEmailUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { user in updatedUser = user }
            $0.authenticationClient.sendVerificationEmail = { _ in verificationCalled = true }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }

        // updateUser called with the new name AND the same email
        #expect(updatedUser?.firstName == "NewName")
        #expect(updatedUser?.email == User.mockUser.email)
        // No verification email sent
        #expect(verificationCalled == false)

        $userInfo.withLock { $0 = nil }
    }

    @Test("confirmEdit with changed email saves other fields immediately")
    func confirmEdit_emailChanged_savesOtherFields() async {
        @Shared(.userInfo) var userInfo
        var originalUser = User.mockUser
        originalUser.email = "old@test.com"
        $userInfo.withLock { $0 = originalUser }

        var changedUser = originalUser
        changedUser.email = "new@test.com"
        changedUser.firstName = "Julie"
        changedUser.lastName = "Dupont"
        changedUser.phoneNumber = "+32 470 99 99 99"

        var savedUser: User?

        let store = TestStore(
            initialState: UserProfileDetailFeature.State(
                destination: .editUser(UserProfileFormFeature.State(wipUser: changedUser))
            )
        ) {
            UserProfileDetailFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { user in savedUser = user }
            $0.authenticationClient.sendVerificationEmail = { _ in }
        }

        await store.send(.confirmEditUserButtonTapped) {
            $0.destination = nil
        }

        await store.receive(\._emailVerificationSent) {
            $0.successMessage = "A verification link has been sent to new@test.com. Your email will be updated once you click it."
        }

        // Saved with old email but updated other fields
        #expect(savedUser?.email == "old@test.com")
        #expect(savedUser?.firstName == "Julie")
        #expect(savedUser?.lastName == "Dupont")
        #expect(savedUser?.phoneNumber == "+32 470 99 99 99")

        $userInfo.withLock { $0 = nil }
    }
}
