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
        case editCKRGame(CKRGameFormFeature)
        case alert(AlertState<Action.Alert>)

        enum Action {
            case addNewCKRGame(CKRGameFormFeature.Action)
            case editCKRGame(CKRGameFormFeature.Action)
            case alert(Alert)

            enum Alert {
                case gameAlreadyGenerated
                case confirmMatchCohouses
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
        var currentGame: CKRGame?
        var isLoadingGame: Bool = false
        var isMatchingCohouses: Bool = false
        var error: String?
    }

    enum Action {
        case addNewCKRGameButtonTapped
        case addNewCKRGameForm
        case ckrGameAlreadyExists
        case ckrGameLoaded(CKRGame?)
        case confirmAddCKRGameButtonTapped
        case confirmEditCKRGameButtonTapped
        case confirmMatchCohousesButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case editCKRGameButtonTapped
        case matchCohousesButtonTapped
        case matchCohousesCompleted(MatchResult)
        case matchCohouesesFailed(String)
        case onTask
        case signOut
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
    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .addNewCKRGameButtonTapped:
                    if state.currentGame != nil {
                        return .send(.ckrGameAlreadyExists)
                    }
                    return .send(.addNewCKRGameForm)
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
                case let .ckrGameLoaded(game):
                    state.isLoadingGame = false
                    state.currentGame = game
                    return .none
                case .confirmAddCKRGameButtonTapped:
                    guard case let .some(.addNewCKRGame(formState)) = state.destination
                    else { return .none }

                    let newGame = formState.wipCKRGame
                    state.destination = nil
                    state.currentGame = newGame

                    return .run { _ in
                        _ = self.ckrClient.newGame(newGame)
                    }
                case .confirmEditCKRGameButtonTapped:
                    guard case let .some(.editCKRGame(formState)) = state.destination
                    else { return .none }

                    let updatedGame = formState.wipCKRGame
                    state.destination = nil
                    state.currentGame = updatedGame

                    return .run { _ in
                        _ = self.ckrClient.updateGame(updatedGame)
                    }
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .editCKRGameButtonTapped:
                    guard let game = state.currentGame else { return .none }
                    state.destination = .editCKRGame(CKRGameFormFeature.State(game: game))
                    return .none
                case .confirmMatchCohousesButtonTapped:
                    guard let game = state.currentGame else { return .none }
                    state.isMatchingCohouses = true
                    let gameId = game.id.uuidString
                    return .run { send in
                        let result = await self.ckrClient.matchCohouses(gameId)
                        switch result {
                        case .success(let matchResult):
                            await send(.matchCohousesCompleted(matchResult))
                        case .failure(let error):
                            await send(.matchCohouesesFailed(error.localizedDescription))
                        }
                    }
                case .matchCohousesButtonTapped:
                    guard let game = state.currentGame else { return .none }
                    let count = game.participantsID.count
                    state.destination = .alert(
                        AlertState {
                            TextState("Match cohouses?")
                        } actions: {
                            ButtonState(action: .confirmMatchCohouses) {
                                TextState("Match \(count) cohouses")
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel")
                            }
                        } message: {
                            TextState("This will partition \(count) registered cohouses into groups of 4 based on GPS proximity. This action will overwrite any previous matching.")
                        }
                    )
                    return .none
                case let .matchCohousesCompleted(matchResult):
                    state.isMatchingCohouses = false
                    state.currentGame?.matchedGroups = matchResult.groups
                    state.currentGame?.matchedAt = Date()
                    state.destination = .alert(
                        AlertState {
                            TextState("Matching complete!")
                        } message: {
                            TextState("\(matchResult.groupCount) groups of 4 cohouses have been created successfully.")
                        }
                    )
                    return .none
                case let .matchCohouesesFailed(errorMessage):
                    state.isMatchingCohouses = false
                    state.destination = .alert(
                        AlertState {
                            TextState("Matching failed")
                        } message: {
                            TextState(errorMessage)
                        }
                    )
                    return .none
                case .onTask:
                    state.isLoadingGame = true
                    return .run { send in
                        // Fetch CKR Game
                        if let game = try? await self.ckrClient.getGame().get() {
                            await send(.ckrGameLoaded(game))
                        } else {
                            await send(.ckrGameLoaded(nil))
                        }

                        // Fetch stats
                        if let count = try? await self.userClient.totalUsersCount().get() {
                            await send(.totalUsersUpdated(count))
                        }
                        if let count = try? await self.cohouseClient.totalCohousesCount().get() {
                            await send(.totalCohousesUpdated(count))
                        }
                        if let count = try? await self.challengeClient.totalChallengesCount().get() {
                            await send(.totalChallengesUpdated(count))
                        }
                        if let count = try? await self.challengeClient.activeChallengesCount().get() {
                            await send(.activeChallengesUpdated(count))
                        }
                        if let count = try? await self.challengeClient.nextChallengesCount().get() {
                            await send(.nextChallengesUpdated(count))
                        }
                    }
                case .signOut:
                    return .run { _ in
                        try await self.authenticationClient.signOut()
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
                case .destination(.presented(.alert(.confirmMatchCohouses))):
                    return .send(.confirmMatchCohousesButtonTapped)
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
                // MARK: - Next CKR Game
                nextGameSection

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
                Button {
                    self.store.send(.signOut)
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                }
            }
        }
        .alert(
            $store.scope(
                state: \.destination?.alert,
                action: \.destination.alert
            )
        )
        // Sheet: Create new CKR Game
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
        // Sheet: Edit existing CKR Game
        .sheet(
            item: $store.scope(state: \.destination?.editCKRGame, action: \.destination.editCKRGame)
        ) { editCKRGameStore in
            NavigationStack {
                CKRGameFormView(store: editCKRGameStore)
                    .navigationTitle("Edit CKR Game")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.confirmEditCKRGameButtonTapped)
                            }
                        }
                    }
            }
        }
        .task {
            store.send(.onTask)
        }
    }

    // MARK: - Next CKR Game Section

    @ViewBuilder
    private var nextGameSection: some View {
        Section(header: Text("Next CKR Game")) {
            if store.isLoadingGame {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let game = store.currentGame {
                ForEach(gameInfoItems(game), id: \.label) { item in
                    LabeledContent(item.label, value: item.value)
                        .swipeActions(edge: .trailing) {
                            Button {
                                store.send(.editCKRGameButtonTapped)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                HStack {
                    Text("Status")
                    Spacer()
                    if game.isRegistrationOpen {
                        Text("Open")
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    } else {
                        Text("Closed")
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        store.send(.editCKRGameButtonTapped)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }

                if let matchedGroups = game.matchedGroups, !matchedGroups.isEmpty {
                    LabeledContent("Matched groups", value: "\(matchedGroups.count) groups of 4")
                    if let matchedAt = game.matchedAt {
                        LabeledContent("Matched at", value: matchedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if store.isMatchingCohouses {
                    HStack {
                        Label("Matching cohouses...", systemImage: "arrow.triangle.swap")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Button {
                        store.send(.matchCohousesButtonTapped)
                    } label: {
                        Label("Match cohouses", systemImage: "arrow.triangle.swap")
                    }
                    .disabled(game.participantsID.isEmpty)
                }
            } else {
                Text("No CKR Game planned")
                    .foregroundStyle(.secondary)
                Button {
                    store.send(.addNewCKRGameButtonTapped)
                } label: {
                    Label("Create new CKR Game", systemImage: "plus.circle")
                }
            }
        }
    }

    private struct GameInfoItem {
        let label: String
        let value: String
    }

    private func gameInfoItems(_ game: CKRGame) -> [GameInfoItem] {
        [
            GameInfoItem(label: "Edition", value: "#\(game.editionNumber)"),
            GameInfoItem(label: "Game date", value: game.nextGameDate.formatted(date: .abbreviated, time: .omitted)),
            GameInfoItem(label: "Registration deadline", value: game.registrationDeadline.formatted(date: .abbreviated, time: .omitted)),
            GameInfoItem(label: "Max participants", value: "\(game.maxParticipants)"),
            GameInfoItem(label: "Registered", value: "\(game.participantsID.count) / \(game.maxParticipants)"),
        ]
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
