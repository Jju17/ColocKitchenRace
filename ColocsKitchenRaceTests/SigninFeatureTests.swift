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
            $0.authenticationClient.signIn = { _, _ in .mockUser }
        }

        await store.send(.signinButtonTapped)
    }

    // MARK: - Failed Sign In

    @Test("Failed signin sets error message")
    func failedSignin_setsError() async {
        let store = TestStore(initialState: SigninFeature.State(email: "bad@test.com", password: "wrong")) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signIn = { _, _ in
                throw AuthError.failedWithError("Invalid credentials")
            }
        }

        await store.send(.signinButtonTapped)
        await store.receive(\.signinErrorTriggered) {
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

    // MARK: - Client-side validation

    @Test("Signin with empty fields shows validation error without network call")
    func signinWithEmptyFields_showsError() async {
        var signinCalled = false

        let store = TestStore(initialState: SigninFeature.State(email: "", password: "")) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signIn = { _, _ in
                signinCalled = true
                return .mockUser
            }
        }

        await store.send(.signinButtonTapped) {
            $0.errorMessage = "Please fill in all fields."
        }

        // signIn should NOT be called — validation prevents it
        #expect(signinCalled == false)
    }

    @Test("Signin with whitespace-only email shows validation error")
    func signinWithWhitespaceEmail_showsError() async {
        var signinCalled = false

        let store = TestStore(initialState: SigninFeature.State(email: "   ", password: "password123")) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signIn = { _, _ in
                signinCalled = true
                return .mockUser
            }
        }

        await store.send(.signinButtonTapped) {
            $0.errorMessage = "Please fill in all fields."
        }

        #expect(signinCalled == false)
    }

    @Test("Signin with email but empty password shows validation error")
    func signinWithEmptyPassword_showsError() async {
        let store = TestStore(initialState: SigninFeature.State(email: "test@test.com", password: "")) {
            SigninFeature()
        }

        await store.send(.signinButtonTapped) {
            $0.errorMessage = "Please fill in all fields."
        }
    }

    // MARK: - Google Sign-In

    @Test("Google signin success does not show error")
    func googleSignin_success() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signInWithGoogle = { .mockUser }
        }

        await store.send(.googleSigninButtonTapped)
    }

    @Test("Google signin failure shows error")
    func googleSignin_failure() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signInWithGoogle = {
                throw AuthError.failedWithError("Cancelled")
            }
        }

        await store.send(.googleSigninButtonTapped)

        await store.receive(\.signinErrorTriggered) {
            $0.errorMessage = "Cancelled"
        }
    }

    // MARK: - Apple Sign-In

    @Test("Apple signin success does not show error")
    func appleSignin_success() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signInWithApple = { .mockUser }
        }

        await store.send(.appleSigninButtonTapped)
    }

    @Test("Apple signin failure shows error")
    func appleSignin_failure() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        } withDependencies: {
            $0.authenticationClient.signInWithApple = {
                throw AuthError.failedWithError("Cancelled")
            }
        }

        await store.send(.appleSigninButtonTapped)

        await store.receive(\.signinErrorTriggered) {
            $0.errorMessage = "Cancelled"
        }
    }

    // MARK: - Error Triggered

    @Test("signinErrorTriggered sets error message")
    func signinErrorTriggered_setsMessage() async {
        let store = TestStore(initialState: SigninFeature.State()) {
            SigninFeature()
        }

        await store.send(.signinErrorTriggered("Network timeout")) {
            $0.errorMessage = "Network timeout"
        }
    }
}
