//
//  TabView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct RootFeature {
    @ObservableState
    struct State {
        var selectedTab: Tab = .home
        var challenge = ChallengeFeature.State()
        var cohouse = CohousingFeature.State.noCohousing(NoCohouseFeature.State())
        var home = HomeFeature.State()
    }

    enum Action {
        case tabChanged(Tab)
        case challenge(ChallengeFeature.Action)
        case cohouse(CohousingFeature.Action)
        case home(HomeFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.selectedTab = tab
                return .none
            case .challenge:
                return .none
            case .cohouse:
                return .none
            case .home:
                return .none
            }
        }
    }
}

enum Tab {
    case home, challenges, cohouse
}

struct RootView: View {
    @Perception.Bindable var store: StoreOf<RootFeature>

    var body: some View {
        WithPerceptionTracking {
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

                CohousingView(
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
}

