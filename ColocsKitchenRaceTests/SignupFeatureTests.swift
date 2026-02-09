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

    @Test("Successful signup completes without error")
    func successfulSignup() async {
        let store = TestStore(
            initialState: SignupFeature.State(
                signupUserData: SignupUser(firstName: "Test", lastName: "User", email: "test@test.com", password: "password123")
            )
        ) {
            SignupFeature()
        } withDependencies: {
            $0.authenticationClient.signUp = { _ in .mockUser }
        }

        await store.send(.signupButtonTapped)
    }

    // MARK: - Failed Sign Up

    @Test("Failed signup sets error message")
    func failedSignup_setsError() async {
        let store = TestStore(
            initialState: SignupFeature.State(
                signupUserData: SignupUser(firstName: "Test", lastName: "User", email: "test@test.com", password: "password123")
            )
        ) {
            SignupFeature()
        } withDependencies: {
            $0.authenticationClient.signUp = { _ in
                throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Email already in use"])
            }
        }

        await store.send(.signupButtonTapped)

        await store.receive(\.signupErrorTriggered) {
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

    @Test("Setting focused field updates state via binding")
    func setFocusedField() async {
        let store = TestStore(initialState: SignupFeature.State()) {
            SignupFeature()
        }

        await store.send(.binding(.set(\.focusedField, .name))) {
            $0.focusedField = .name
        }

        await store.send(.binding(.set(\.focusedField, nil))) {
            $0.focusedField = nil
        }
    }

    // MARK: - Client-side validation

    @Test("Signup with empty fields shows validation error without network call")
    func signupWithEmptyFields_showsError() async {
        var signupCalled = false

        let store = TestStore(initialState: SignupFeature.State(signupUserData: SignupUser())) {
            SignupFeature()
        } withDependencies: {
            $0.authenticationClient.signUp = { _ in
                signupCalled = true
                return .mockUser
            }
        }

        await store.send(.signupButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }

        // signUp should NOT be called — validation prevents it
        #expect(signupCalled == false)
    }

    // MARK: - Phone number preserved

    @Test("SignupUser.createUser preserves phone number")
    func createUserPreservesPhone() {
        let signupData = SignupUser(
            firstName: "Julien",
            lastName: "Rahier",
            email: "julien@test.com",
            password: "12345678",
            phone: "+32479506841"
        )

        let user = signupData.createUser(authId: "firebase-uid-123")

        #expect(user.phoneNumber == "+32479506841")
        #expect(user.firstName == "Julien")
        #expect(user.lastName == "Rahier")
        #expect(user.email == "julien@test.com")
    }

    @Test("SignupUser.createUser sets nil phone when empty")
    func createUserEmptyPhone() {
        let signupData = SignupUser(
            firstName: "Test",
            lastName: "User",
            email: "test@test.com",
            password: "password"
        )

        let user = signupData.createUser(authId: "auth-123")
        #expect(user.phoneNumber == nil)
    }
}
