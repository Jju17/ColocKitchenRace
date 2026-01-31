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
        var news = NewsFeature.State()
        var notification = NotificationFeature.State()
    }

    enum Action {
        case tabChanged(Tab)
        case challenge(ChallengeFeature.Action)
        case challengeValidation(ChallengeValidationFeature.Action)
        case home(HomeFeature.Action)
        case news(NewsFeature.Action)
        case notification(NotificationFeature.Action)
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

        Scope(state: \.news, action: \.news) {
            NewsFeature()
        }

        Scope(state: \.notification, action: \.notification) {
            NotificationFeature()
        }

        Reduce { state, action in
            switch action {
                case let .tabChanged(tab):
                    state.selectedTab = tab
                    return .none
                case .challenge:
                    return .none
                case .challengeValidation:
                    return .none
                case .home:
                    return .none
                case .news:
                    return .none
                case .notification:
                    return .none
            }
        }
    }
}

enum Tab {
    case challenge
    case challengeValidation
    case home
    case news
    case notification
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
            NewsView(
                store: self.store.scope(
                    state: \.news,
                    action: \.news
                )
            )
            .tabItem {
                Label("News", systemImage: "newspaper.fill")
            }
            .tag(Tab.news)
            NotificationView(
                store: self.store.scope(
                    state: \.notification,
                    action: \.notification
                )
            )
            .tabItem {
                Label("Notifs", systemImage: "bell.fill")
            }
            .tag(Tab.notification)
        }
    }
}

