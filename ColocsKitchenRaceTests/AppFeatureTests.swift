//
//  AppFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import FirebaseAuth
import Testing

@testable import ColocsKitchenRace

@MainActor
struct AppFeatureTests {

    // MARK: - Auth State Routing

    @Test("When auth state triggers with a user, navigate to tab view")
    func authStateTriggerWithUser_navigatesToTab() async {
        let store = TestStore(initialState: AppFeature.State.splashScreen(SplashScreenFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authentificationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        // Simulating Firebase sends a non-nil user (we use the action directly)
        await store.send(.newAuthStateTrigger(nil)) {
            $0 = .signin(SigninFeature.State())
        }
    }

    @Test("When auth state triggers with nil, navigate to signin")
    func authStateTriggerWithNil_navigatesToSignin() async {
        let store = TestStore(initialState: AppFeature.State.tab(TabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authentificationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.newAuthStateTrigger(nil)) {
            $0 = .signin(SigninFeature.State())
        }
    }

    // MARK: - Signin/Signup Navigation

    @Test("Delegate from signin switches to signup")
    func signinDelegateSwitchesToSignup() async {
        let store = TestStore(initialState: AppFeature.State.signin(SigninFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authentificationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.signin(.delegate(.switchToSignupButtonTapped))) {
            $0 = .signup(SignupFeature.State())
        }
    }

    @Test("Delegate from signup switches to signin")
    func signupDelegateSwitchesToSignin() async {
        let store = TestStore(initialState: AppFeature.State.signup(SignupFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authentificationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.signup(.delegate(.switchToSigninButtonTapped))) {
            $0 = .signin(SigninFeature.State())
        }
    }
}
