//
//  SigninFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing

@testable import ColocsKitchenRace

@MainActor
struct SigninFeatureTests {

    // MARK: - Successful Sign In

    @Test("Successful signin does not set error")
    func successfulSignin() async {
        let store = TestStore(initialState: SigninFeature.State(email: "test@test.com", password: "password123")) {
            SigninFeature()
        } withDependencies: {
            $0.authentificationClient.signIn = { _, _ in .mockUser }
        }

        await store.send(.signinButtonTapped)
    }

    // MARK: - Failed Sign In

    @Test("Failed signin sets error message")
    func failedSignin_setsError() async {
        let store = TestStore(initialState: SigninFeature.State(email: "bad@test.com", password: "wrong")) {
            SigninFeature()
        } withDependencies: {
            $0.authentificationClient.signIn = { _, _ in
                throw AuthError.failedWithError("Invalid credentials")
            }
        }

        await store.send(.signinButtonTapped)
        await store.receive(\.signinErrorTrigered) {
            $0.errorMessage = "Invalid credentials"
        }
    }

    // MARK: - Navigation

    @Test("Switch to signup delegates correctly")
    func switchToSignup() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        }

        await store.send(.switchToSignupButtonTapped)
        await store.receive(\.delegate.switchToSignupButtonTapped)
    }

    // MARK: - Binding

    @Test("Email and password fields bind correctly")
    func fieldsBinding() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        }

        await store.send(\.binding.email, "user@example.com") {
            $0.email = "user@example.com"
        }

        await store.send(\.binding.password, "secret") {
            $0.password = "secret"
        }
    }

    // MARK: - Bug: Empty email/password still triggers signin

    @Test("BUG: Signin with empty fields still fires network request - no client-side validation")
    func signinWithEmptyFields_stillCallsClient() async {
        var signinCalled = false

        let store = TestStore(initialState: SigninFeature.State(email: "", password: "")) {
            SigninFeature()
        } withDependencies: {
            $0.authentificationClient.signIn = { _, _ in
                signinCalled = true
                throw AuthError.failedWithError("Empty fields")
            }
        }

        await store.send(.signinButtonTapped)
        await store.receive(\.signinErrorTrigered) {
            $0.errorMessage = "Empty fields"
        }

        // BUG: signIn is called even with empty email/password
        // There's no client-side validation before making the network call
        #expect(signinCalled == true)
    }
}
