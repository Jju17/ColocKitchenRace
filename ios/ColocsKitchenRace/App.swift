//
//  App.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//
import ComposableArchitecture
import FirebaseAuth
import os
import SwiftUI

@Reducer
struct AppFeature {
    @ObservableState
    @CasePathable
    enum State: Equatable {
        case tab(TabFeature.State)
        case signin(SignInFeature.State)
        case profileCompletion(ProfileCompletionFeature.State)
        case emailVerification(EmailVerificationFeature.State)
        case splashScreen(SplashScreenFeature.State)
    }

    @CasePathable
    enum Action {
        case onTask
        case tab(TabFeature.Action)
        case signin(SignInFeature.Action)
        case profileCompletion(ProfileCompletionFeature.Action)
        case emailVerification(EmailVerificationFeature.Action)
        case splashScreen(SplashScreenFeature.Action)
        case newAuthStateTrigger(FirebaseAuth.User?)
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    for await user in self.authenticationClient.listenAuthState() {
                        await send(.newAuthStateTrigger(user))
                    }
                }
            case let .newAuthStateTrigger(user):
                if let user {
                    if user.isEmailVerified {
                        @Shared(.userInfo) var userInfo

                        // Post-reinstall recovery: Firebase Auth session survives in Keychain,
                        // but FileStorage data is wiped. Re-fetch from Firestore.
                        if userInfo == nil {
                            state = .splashScreen(SplashScreenFeature.State())
                            return .run { send in
                                do {
                                    let profile = try await self.authenticationClient.fetchProfile(user.uid)
                                    if let profile, !profile.needsProfileCompletion {
                                        // Profile restored — re-trigger auth flow
                                        await send(.newAuthStateTrigger(user))
                                    } else {
                                        // No Firestore profile or incomplete — force profile completion
                                        await send(.newAuthStateTrigger(user))
                                    }
                                } catch {
                                    Logger.authLog.error("[AppFeature] Failed to fetch profile: \(error)")
                                    // Can't recover — sign out and let user re-login
                                    try? await self.authenticationClient.signOut()
                                }
                            }
                        }

                        // Sync Firebase Auth email → Firestore if changed (e.g. after email re-verification)
                        var syncEffect: Effect<Action> = .none
                        let authEmail = user.email
                        let firestoreEmail = userInfo?.email
                        if let authEmail, authEmail != firestoreEmail, var updatedUser = userInfo {
                            updatedUser.email = authEmail
                            $userInfo.withLock { $0 = updatedUser }
                            let userToSync = updatedUser
                            syncEffect = .run { _ in
                                try await self.authenticationClient.updateUser(userToSync)
                            } catch: { _, _ in }
                        }

                        if let currentUser = userInfo, currentUser.needsProfileCompletion {
                            state = .profileCompletion(ProfileCompletionFeature.State())
                        } else {
                            state = .tab(TabFeature.State())
                        }
                        return syncEffect
                    } else {
                        state = .emailVerification(EmailVerificationFeature.State())
                    }
                } else {
                    state = .signin(SignInFeature.State())
                }
                return .none
            case .profileCompletion(.delegate(.profileCompleted)):
                state = .tab(TabFeature.State())
                return .none
            case .emailVerification(.delegate(.emailVerified)):
                @Shared(.userInfo) var userInfo
                if let currentUser = userInfo, currentUser.needsProfileCompletion {
                    state = .profileCompletion(ProfileCompletionFeature.State())
                } else {
                    state = .tab(TabFeature.State())
                }
                return .none
            case .tab, .signin, .profileCompletion, .emailVerification, .splashScreen:
                return .none
            }
        }
        .ifCaseLet(\.tab, action: \.tab) { TabFeature() }
        .ifCaseLet(\.signin, action: \.signin) { SignInFeature() }
        .ifCaseLet(\.profileCompletion, action: \.profileCompletion) { ProfileCompletionFeature() }
        .ifCaseLet(\.emailVerification, action: \.emailVerification) { EmailVerificationFeature() }
        .ifCaseLet(\.splashScreen, action: \.splashScreen) { SplashScreenFeature() }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.state {
            case .tab:
                if let rootStore = store.scope(state: \.tab, action: \.tab) {
                    MyTabView(store: rootStore)
                }
            case .signin:
                if let signinStore = store.scope(state: \.signin, action: \.signin) {
                    SignInView(store: signinStore)
                }
            case .profileCompletion:
                if let profileStore = store.scope(state: \.profileCompletion, action: \.profileCompletion) {
                    ProfileCompletionView(store: profileStore)
                }
            case .emailVerification:
                if let verificationStore = store.scope(state: \.emailVerification, action: \.emailVerification) {
                    EmailVerificationView(store: verificationStore)
                }
            case .splashScreen:
                if let splashScreenStore = store.scope(state: \.splashScreen, action: \.splashScreen) {
                    SplashScreenView(store: splashScreenStore)
                }
            }
        }
        .task {
            self.store.send(.onTask)
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State.tab(TabFeature.State())) {
            AppFeature()
        }
    )
}
