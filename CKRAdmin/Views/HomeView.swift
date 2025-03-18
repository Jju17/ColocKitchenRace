//
//  HomeView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

@Reducer
struct HomeFeature {

    @ObservableState
    struct State {
        var totalUsers = 0
        var totalCohouses = 0
        var totalChallenges = 0
        var activeChallenges = 0
        var nextChallenges = 0
    }

    enum Action {
        case onTask
        case totalUsersUpdated(Int)
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    let totalUsersCountResult = try await self.userClient.totalUsersCount()
                    let totalUsersCount = (try? totalUsersCountResult.get()) ?? 0

                    await send(.totalUsersUpdated(totalUsersCount))
                }
            case let .totalUsersUpdated(count):
                state.totalUsers = count
                return .none
            }
        }
    }
}

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Global")) {
                    HStack {
                        Text("Total users :")
                        Text("\(self.store.totalUsers)")
                    }
                }
                Section(header: Text("Cohouses")) {
                    HStack {
                        Text("Total cohouses :")
                        Text("\(self.store.totalCohouses)")
                    }
                }
                Section(header: Text("Challenges")) {
                    HStack {
                        Text("Total challenges :")
                        Text("\(self.store.totalChallenges)")
                    }
                    HStack {
                        Text("Active challenges at the moment :")
                        Text("\(self.store.activeChallenges)")
                    }
                    HStack {
                        Text("Next challenges :")
                        Text("\(self.store.nextChallenges)")
                    }
                }
            }
            .navigationTitle("Stats")
        }
        .task {
            store.send(.onTask)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }

}
