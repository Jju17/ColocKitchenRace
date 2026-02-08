//
//  SignupFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct SignupFeatureTests {

    // MARK: - Successful Sign Up

    @Test("Successful signup breaks without doing anything - BUG: no navigation or feedback")
    func successfulSignup_noNavigation() async {
        let store = TestStore(initialState: SignupFeature.State()) {
            SignupFeature()
        } withDependencies: {
            $0.authentificationClient.signUp = { _ in
                .success(User.mockUser)
            }
        }

        await store.send(.signupButtonTapped)
        // BUG: On success, the reducer just `break`s.
        // The user sees no confirmation, no navigation.
        // The auth state listener in AppFeature should eventually transition,
        // but there's a race condition: if Firebase hasn't propagated the auth state
        // change yet, the user is stuck on the signup screen.
    }

    // MARK: - Failed Sign Up

    @Test("Failed signup sets error message")
    func failedSignup_setsError() async {
        let store = TestStore(initialState: SignupFeature.State()) {
            SignupFeature()
        } withDependencies: {
            $0.authentificationClient.signUp = { _ in
                .failure(NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Email already in use"]))
            }
        }

        await store.send(.signupButtonTapped)

        await store.receive(\.signupErrorTrigered) {
            $0.errorMessage = "Email already in use"
        }
    }

    // MARK: - Navigation

    @Test("Switch to signin delegates correctly")
    func switchToSignin() async {
        let store = TestStore(initialState: SignupFeature.State()) {
            SignupFeature()
        }

        await store.send(.goToSigninButtonTapped)
        await store.receive(\.delegate.switchToSigninButtonTapped)
    }

    // MARK: - Focused Field

    @Test("Setting focused field updates state")
    func setFocusedField() async {
        let store = TestStore(initialState: SignupFeature.State()) {
            SignupFeature()
        }

        await store.send(.setFocusedField(.name)) {
            $0.focusedField = .name
        }

        await store.send(.setFocusedField(nil)) {
            $0.focusedField = nil
        }
    }

    // MARK: - Bug: No form validation

    @Test("BUG: Signup with empty fields still fires network request")
    func signupWithEmptyFields() async {
        var signupCalled = false

        let store = TestStore(initialState: SignupFeature.State(signupUserData: SignupUser())) {
            SignupFeature()
        } withDependencies: {
            $0.authentificationClient.signUp = { _ in
                signupCalled = true
                return .failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty fields"]))
            }
        }

        await store.send(.signupButtonTapped)
        await store.receive(\.signupErrorTrigered) {
            $0.errorMessage = "Empty fields"
        }

        // BUG: No client-side validation for required fields
        #expect(signupCalled == true)
    }

    // MARK: - Bug: Phone number lost during signup

    @Test("BUG: SignupUser.createUser drops phone number")
    func createUserDropsPhone() {
        let signupData = SignupUser(
            firstName: "Julien",
            lastName: "Rahier",
            email: "julien@test.com",
            password: "12345678",
            phone: "+32479506841"
        )

        let user = signupData.createUser(authId: "firebase-uid-123")

        // BUG: phoneNumber is hardcoded to nil in createUser
        // even though the user entered a phone number
        #expect(user.phoneNumber == nil)
        #expect(user.firstName == "Julien")
        #expect(user.lastName == "Rahier")
        #expect(user.email == "julien@test.com")
    }
}
