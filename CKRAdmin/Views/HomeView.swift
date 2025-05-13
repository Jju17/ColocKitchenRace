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
        struct UsersState {
            var total = 0
        }
        struct CohousesState {
            var total = 0
        }
        struct ChallengesState {
            var total = 0
            var active = 0
            var next = 0
        }
        var users = UsersState()
        var cohouses = CohousesState()
        var challenges = ChallengesState()
        var error: String?
    }

    enum Action {
        case onTask
        case totalUsersUpdated(Int)
        case totalCohousesUpdated(Int)
        case totalChallengesUpdated(Int)
        case activeChallengesUpdated(Int)
        case nextChallengesUpdated(Int)
        case errorOccurred(String)
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.challengeClient) var challengeClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onTask:
                    return .run { send in
                        async let users = self.userClient.totalUsersCount().get()
                        async let cohouses = self.cohouseClient.totalCohousesCount().get()
                        async let totalChallenges = self.challengeClient.totalChallengesCount().get()
                        async let activeChallenges = self.challengeClient.activeChallengesCount().get()
                        async let nextChallenges = self.challengeClient.nextChallengesCount().get()

                        if let usersCount = try? await users {
                            await send(.totalUsersUpdated(usersCount))
                        }
                        if let cohousesCount = try? await cohouses {
                            await send(.totalCohousesUpdated(cohousesCount))
                        }
                        if let totalChallengesCount = try? await totalChallenges {
                            await send(.totalChallengesUpdated(totalChallengesCount))
                        }
                        if let activeChallengesCount = try? await activeChallenges {
                            await send(.activeChallengesUpdated(activeChallengesCount))
                        }
                        if let nextChallengesCount = try? await nextChallenges {
                            await send(.nextChallengesUpdated(nextChallengesCount))
                        }
                    }
                case let .totalUsersUpdated(count):
                    state.users.total = count
                    return .none
                case let .totalCohousesUpdated(count):
                    state.cohouses.total = count
                    return .none
                case let .totalChallengesUpdated(count):
                    state.challenges.total = count
                    return .none
                case let .activeChallengesUpdated(count):
                    state.challenges.active = count
                    return .none
                case let .nextChallengesUpdated(count):
                    state.challenges.next = count
                    return .none
                case let .errorOccurred(error):
                    state.error = error
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
                        Text("\(self.store.users.total)")
                    }
                }
                Section(header: Text("Cohouses")) {
                    HStack {
                        Text("Total cohouses :")
                        Text("\(self.store.cohouses.total)")
                    }
                }
                Section(header: Text("Challenges")) {
                    HStack {
                        Text("Total challenges :")
                        Text("\(self.store.challenges.total)")
                    }
                    HStack {
                        Text("Active challenges at the moment :")
                        Text("\(self.store.challenges.active)")
                    }
                    HStack {
                        Text("Next challenges :")
                        Text("\(self.store.challenges.next)")
                    }
                }
                if let error = store.error {
                    Section(header: Text("Error")) {
                        Text(error)
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
