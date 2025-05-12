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
        var home = HomeFeature.State()
    }
    
    enum Action {
        case tabChanged(Tab)
        case challenge(ChallengeFeature.Action)
        case home(HomeFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.challenge, action: \.challenge) {
            ChallengeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.selectedTab = tab
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
                Label("Challenge", systemImage: "flag.2.crossed.fill")
            }
            .tag(Tab.challenge)
        }
    }
}

