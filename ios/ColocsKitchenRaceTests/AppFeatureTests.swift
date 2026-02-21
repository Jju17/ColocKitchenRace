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

    @Test("When auth state triggers with nil, navigate to signin")
    func authStateTriggerWithNil_navigatesToSignin() async {
        let store = TestStore(initialState: AppFeature.State.tab(TabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authenticationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.newAuthStateTrigger(nil)) {
            $0 = .signin(SigninFeature.State())
        }
    }

    @Test("When auth state triggers with nil from splash, navigate to signin")
    func authStateTriggerFromSplash_navigatesToSignin() async {
        let store = TestStore(initialState: AppFeature.State.splashScreen(SplashScreenFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authenticationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.newAuthStateTrigger(nil)) {
            $0 = .signin(SigninFeature.State())
        }
    }

    // MARK: - Profile Completion Routing

    @Test("Auth state with complete profile navigates to tab")
    func authStateTriggerWithCompleteProfile_navigatesToTab() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        let store = TestStore(initialState: AppFeature.State.emailVerification(EmailVerificationFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authenticationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        // mockUser has firstName, lastName, and phoneNumber set — profile is complete
        await store.send(.emailVerification(.delegate(.emailVerified))) {
            $0 = .tab(TabFeature.State())
        }

        // Cleanup shared state
        $userInfo.withLock { $0 = nil }
    }

    @Test("Auth state with incomplete profile navigates to profileCompletion")
    func authStateTriggerWithIncompleteProfile_navigatesToProfileCompletion() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock {
            $0 = User(id: UUID(), authProvider: .email, firstName: "", lastName: "", email: "test@test.com")
        }

        let store = TestStore(initialState: AppFeature.State.emailVerification(EmailVerificationFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authenticationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.emailVerification(.delegate(.emailVerified))) {
            $0 = .profileCompletion(ProfileCompletionFeature.State())
        }

        // Cleanup shared state
        $userInfo.withLock { $0 = nil }
    }

    // MARK: - Profile Completion Delegate

    @Test("Delegate profileCompleted transitions to tab")
    func profileCompletedDelegate_navigatesToTab() async {
        let store = TestStore(initialState: AppFeature.State.profileCompletion(ProfileCompletionFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.authenticationClient.listenAuthState = { AsyncStream { $0.finish() } }
        }

        await store.send(.profileCompletion(.delegate(.profileCompleted))) {
            $0 = .tab(TabFeature.State())
        }
    }
}
