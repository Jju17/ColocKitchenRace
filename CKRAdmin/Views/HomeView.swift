//
//  HomeView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {

    @Reducer
    enum Destination {
        case addNewCKRGame(CKRGameFormFeature)
        case alert(AlertState<Action.Alert>)

        enum Action {
            case addNewCKRGame(CKRGameFormFeature.Action)
            case alert(Alert)

            enum Alert {
                case gameAlreadyGenerated
            }
        }
    }

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
        @Presents var destination: Destination.State?
        var users = UsersState()
        var cohouses = CohousesState()
        var challenges = ChallengesState()
        var error: String?
    }

    enum Action {
        case addNewCKRGameButtonTapped
        case addNewCKRGameForm
        case ckrGameAlreadyExists
        case confirmAddCKRGameButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
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
    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .addNewCKRGameButtonTapped:
                    return .run { send in
                        guard try await self.ckrClient.getGame().get() != nil else {
                            await send(.addNewCKRGameForm)
                            return
                        }

                        await send(.ckrGameAlreadyExists)
                    }
                case .addNewCKRGameForm:
                    state.destination = .addNewCKRGame(CKRGameFormFeature.State())
                    return .none
                case .ckrGameAlreadyExists:
                    state.destination = .alert(
                        AlertState {
                            TextState("CKR Game already exists")
                        } message: {
                            TextState("For now, if you want to delete current game, please check with an Admin.")
                        }
                    )
                    return .none
                case .confirmAddCKRGameButtonTapped:
                    guard case let .some(.addNewCKRGame(ckrGameFormFeature)) = state.destination
                    else { return .none }

                    let newGame = ckrGameFormFeature.wipCKRGame
                    state.destination = nil

                    return .run { _ in
                        _ = self.ckrClient.newGame(newGame)
                    }
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
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
                case .destination:
                    return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
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
            .navigationTitle("Dashboard")
            .toolbar {
                Button {
                    self.store.send(.addNewCKRGameButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(
            $store.scope(
                state: \.destination?.alert,
                action: \.destination.alert
            )
        )
        .sheet(
            item: $store.scope(state: \.destination?.addNewCKRGame, action: \.destination.addNewCKRGame)
        ) { addNewCKRGameStore in
            NavigationStack {
                CKRGameFormView(store: addNewCKRGameStore)
                    .navigationTitle("New CKR Game")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                store.send(.confirmAddCKRGameButtonTapped)
                            }
                        }
                    }
            }
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
