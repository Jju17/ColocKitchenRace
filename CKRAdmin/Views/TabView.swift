//
//  TabView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct TabFeature {
    @ObservableState
    struct State {
        var selectedTab: Tab = .home
        var challenge = ChallengeFeature.State()
        var challengeValidation = ChallengeValidationFeature.State()
        var home = HomeFeature.State()
    }

    enum Action {
        case tabChanged(Tab)
        case challenge(ChallengeFeature.Action)
        case challengeValidation(ChallengeValidationFeature.Action)
        case home(HomeFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.challenge, action: \.challenge) {
            ChallengeFeature()
        }

        Scope(state: \.challengeValidation, action: \.challengeValidation) {
            ChallengeValidationFeature()
        }

        Reduce { state, action in
            switch action {
                case let .tabChanged(tab):
                    state.selectedTab = tab
                    return .none
                case .challengeValidation:
                    return .none
                case .challenge:
                    return .none
                case .home:
                    return .none
            }
        }
    }
}

enum Tab {
    case challenge
    case challengeValidation
    case home
}

struct MyTabView: View {
    @Bindable var store: StoreOf<TabFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabChanged)) {
            HomeView(
                store: self.store.scope(
                    state: \.home,
                    action: \.home
                )
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)
            ChallengeView(
                store: self.store.scope(
                    state: \.challenge,
                    action: \.challenge
                )
            )
            .tabItem {
                Label("Challenges", systemImage: "flag.2.crossed.fill")
            }
            .tag(Tab.challenge)
            ChallengeValidationView(
                store: self.store.scope(
                    state: \.challengeValidation,
                    action: \.challengeValidation
                )
            )
            .tabItem {
                Label("Validation", systemImage: "checklist.checked")
            }
            .tag(Tab.challengeValidation)
        }
    }
}

