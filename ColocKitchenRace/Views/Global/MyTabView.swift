//
//  MyTabView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct TabFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var challenge = ChallengeFeature.State()
        var cohouse = CohouseFeature.State()
        var home = HomeFeature.State()
        var planning = PlanningFeature.State()
    }

    enum Action {
        case tabChanged(Tab)
        case challenge(ChallengeFeature.Action)
        case cohouse(CohouseFeature.Action)
        case home(HomeFeature.Action)
        case planning(PlanningFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.challenge, action: \.challenge) {
            ChallengeFeature()
        }
        Scope(state: \.cohouse, action: \.cohouse) {
            CohouseFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.planning, action: \.planning) {
            PlanningFeature()
        }

        Reduce { state, action in
            switch action {
                case let .tabChanged(tab):
                    state.selectedTab = tab
                    return .none
                case .home(.delegate(.switchToCohouseButtonTapped)):
                    state.selectedTab = .cohouse
                    return .none
                case .challenge(.delegate(.switchToCohouseButtonTapped)):
                      state.selectedTab = .cohouse
                      return .none
                case .challenge, .cohouse, .home, .planning:
                    return .none
            }
        }
    }
}

enum Tab: Equatable {
    case home, challenges, planning, cohouse
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
                Label("Challenges", systemImage: "star.fill")
            }
            .tag(Tab.challenges)

            if store.planning.isRevealed && store.planning.isRegistered {
                PlanningView(
                    store: self.store.scope(
                        state: \.planning,
                        action: \.planning
                    )
                )
                .tabItem {
                    Label("Planning", systemImage: "calendar")
                }
                .tag(Tab.planning)
            }

            CohouseView(
                store: self.store.scope(
                    state: \.cohouse,
                    action: \.cohouse
                )
            )
            .tabItem {
                Label("Cohouse", systemImage: "person.3.fill")
            }
            .tag(Tab.cohouse)
        }
    }
}

