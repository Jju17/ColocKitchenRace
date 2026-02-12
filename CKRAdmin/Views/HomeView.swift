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
        case matchedGroupsMap(MatchedGroupsMapFeature)
        case alert(AlertState<Action.Alert>)

        enum Action {
            case addNewCKRGame(CKRGameFormFeature.Action)
            case editCKRGame(CKRGameFormFeature.Action)
            case matchedGroupsMap(MatchedGroupsMapFeature.Action)
            case alert(Alert)

            enum Alert {
                case gameAlreadyGenerated
                case confirmMatchCohouses
                case confirmResetMatches
                case confirmDeleteGame
                case confirmEditGame
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
        case deleteGameButtonTapped
        case confirmDeleteGameButtonTapped
        case deleteGameCompleted
        case deleteGameFailed(String)
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case editCKRGameButtonTapped
        case matchCohousesButtonTapped
        case matchCohousesCompleted(MatchResult)
        case matchCohouesesFailed(String)
        case onTask
        case resetMatchesButtonTapped
        case confirmResetMatchesButtonTapped
        case resetMatchesCompleted
        case resetMatchesFailed(String)
        case viewMatchedGroupsMapButtonTapped
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
                case .deleteGameButtonTapped:
                    guard let game = state.currentGame else { return .none }
                    let warning = game.hasCountdownStarted
                        ? "\n\n⚠️ The CKR countdown has already started (\(game.startCKRCountdown.formatted(date: .abbreviated, time: .omitted)))."
                        : ""
                    state.destination = .alert(
                        AlertState {
                            TextState("Delete CKR Game?")
                        } actions: {
                            ButtonState(role: .destructive, action: .confirmDeleteGame) {
                                TextState("Delete")
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel")
                            }
                        } message: {
                            TextState("Are you sure? This will permanently delete the current CKR Game and all its data (participants, matches, etc.).\(warning)")
                        }
                    )
                    return .none
                case .confirmDeleteGameButtonTapped:
                    return .run { send in
                        let result = await self.ckrClient.deleteGame()
                        switch result {
                        case .success:
                            await send(.deleteGameCompleted)
                        case .failure(let error):
                            await send(.deleteGameFailed(error.localizedDescription))
                        }
                    }
                case .deleteGameCompleted:
                    state.currentGame = nil
                    return .none
                case let .deleteGameFailed(errorMessage):
                    state.destination = .alert(
                        AlertState {
                            TextState("Delete failed")
                        } message: {
                            TextState(errorMessage)
                        }
                    )
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .editCKRGameButtonTapped:
                    guard state.currentGame != nil else { return .none }
                    state.destination = .alert(
                        AlertState {
                            TextState("Beta Feature")
                        } actions: {
                            ButtonState(action: .confirmEditGame) {
                                TextState("I understand, continue")
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel")
                            }
                        } message: {
                            TextState("Editing a CKR Game is a beta feature. Modifying certain fields while a game is in progress may cause unexpected behavior.")
                        }
                    )
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
                    let count = game.cohouseIDs.count
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
                case .resetMatchesButtonTapped:
                    state.destination = .alert(
                        AlertState {
                            TextState("Reset all matches?")
                        } actions: {
                            ButtonState(role: .destructive, action: .confirmResetMatches) {
                                TextState("Reset")
                            }
                            ButtonState(role: .cancel) {
                                TextState("Cancel")
                            }
                        } message: {
                            TextState("Are you sure? This will permanently remove all matched groups from the current game. This action is not reversible.")
                        }
                    )
                    return .none
                case .confirmResetMatchesButtonTapped:
                    guard let game = state.currentGame else { return .none }
                    let gameId = game.id.uuidString
                    return .run { send in
                        let result = await self.ckrClient.resetMatches(gameId)
                        switch result {
                        case .success:
                            await send(.resetMatchesCompleted)
                        case .failure(let error):
                            await send(.resetMatchesFailed(error.localizedDescription))
                        }
                    }
                case .resetMatchesCompleted:
                    state.currentGame?.matchedGroups = nil
                    state.currentGame?.matchedAt = nil
                    return .run { send in
                        if let game = try? await self.ckrClient.getGame().get() {
                            await send(.ckrGameLoaded(game))
                        }
                    }
                case let .resetMatchesFailed(errorMessage):
                    state.destination = .alert(
                        AlertState {
                            TextState("Reset failed")
                        } message: {
                            TextState(errorMessage)
                        }
                    )
                    return .none
                case .onTask:
                    state.isLoadingGame = true
                    return .merge(
                        .run { send in
                            for await game in self.ckrClient.watchGame() {
                                await send(.ckrGameLoaded(game))
                            }
                        },
                        .run { send in
                            for await count in self.userClient.watchTotalUsersCount() {
                                await send(.totalUsersUpdated(count))
                            }
                        },
                        .run { send in
                            for await count in self.cohouseClient.watchTotalCohousesCount() {
                                await send(.totalCohousesUpdated(count))
                            }
                        },
                        .run { send in
                            for await counts in self.challengeClient.watchChallengesCounts() {
                                await send(.totalChallengesUpdated(counts.total))
                                await send(.activeChallengesUpdated(counts.active))
                                await send(.nextChallengesUpdated(counts.next))
                            }
                        }
                    )
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
                case .viewMatchedGroupsMapButtonTapped:
                    guard let groups = state.currentGame?.matchedGroups else { return .none }
                    state.destination = .matchedGroupsMap(
                        MatchedGroupsMapFeature.State(matchedGroups: groups)
                    )
                    return .none
                case .destination(.presented(.alert(.confirmMatchCohouses))):
                    return .send(.confirmMatchCohousesButtonTapped)
                case .destination(.presented(.alert(.confirmResetMatches))):
                    return .send(.confirmResetMatchesButtonTapped)
                case .destination(.presented(.alert(.confirmDeleteGame))):
                    return .send(.confirmDeleteGameButtonTapped)
                case .destination(.presented(.alert(.confirmEditGame))):
                    guard let game = state.currentGame else { return .none }
                    state.destination = .editCKRGame(CKRGameFormFeature.State(game: game))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if store.currentGame != nil {
                            Button {
                                store.send(.editCKRGameButtonTapped)
                            } label: {
                                Label("Edit CKR Game (Beta)", systemImage: "exclamationmark.triangle")
                            }

                            Button(role: .destructive) {
                                store.send(.deleteGameButtonTapped)
                            } label: {
                                Label("Delete CKR Game", systemImage: "trash")
                            }
                        } else {
                            Button {
                                store.send(.addNewCKRGameButtonTapped)
                            } label: {
                                Label("New CKR Game", systemImage: "plus")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            store.send(.signOut)
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.forward")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
        // Sheet: Matched Groups Map
        .sheet(
            item: $store.scope(state: \.destination?.matchedGroupsMap, action: \.destination.matchedGroupsMap)
        ) { mapStore in
            NavigationStack {
                MatchedGroupsMapView(store: mapStore)
                    .navigationTitle("Matched Groups")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                store.send(.dismissDestinationButtonTapped)
                            } label: {
                                Label("Close", systemImage: "xmark")
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
                    Button {
                        store.send(.viewMatchedGroupsMapButtonTapped)
                    } label: {
                        HStack {
                            Text("Matched groups")
                            Spacer()
                            Text("\(matchedGroups.count) groups of 4")
                                .foregroundStyle(.secondary)
                            Image(systemName: "map")
                                .foregroundStyle(.blue)
                        }
                    }
                    .foregroundStyle(.primary)
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
                    .disabled(game.cohouseIDs.isEmpty)
                }

                if game.matchedGroups != nil {
                    Button(role: .destructive) {
                        store.send(.resetMatchesButtonTapped)
                    } label: {
                        Label("Reset matches", systemImage: "arrow.counterclockwise")
                    }
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
            GameInfoItem(label: "Countdown start", value: game.startCKRCountdown.formatted(date: .abbreviated, time: .omitted)),
            GameInfoItem(label: "Registration deadline", value: game.registrationDeadline.formatted(date: .abbreviated, time: .omitted)),
            GameInfoItem(label: "Game date", value: game.nextGameDate.formatted(date: .abbreviated, time: .omitted)),
            GameInfoItem(label: "Max participants", value: "\(game.maxParticipants)"),
            GameInfoItem(label: "Price per person", value: game.formattedPricePerPerson),
            GameInfoItem(label: "Registered", value: "\(game.totalRegisteredParticipants) / \(game.maxParticipants) participants (\(game.cohouseIDs.count) cohouses)"),
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
