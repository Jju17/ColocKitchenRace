//
//  ChallengeView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 5/11/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ChallengeFeature {

    @Reducer
    enum Destination {
        case addChallenge(ChallengeFormFeature)
        case alert(AlertState<Action.Alert>)

        enum Action {
            case addChallenge(ChallengeFormFeature.Action)
            case alert(Alert)

            enum Alert {
                case deleteChallenge
            }
        }
    }

    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
        var challenges: [Challenge] = []
        var challengeToDelete: Challenge?
    }

    enum Action: BindableAction {
        case addChallengeButtonTapped
        case binding(BindingAction<State>)
        case challengeUpdated([Challenge])
        case confirmAddChallengeButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case deleteChallenge(Challenge)
        case confirmDeleteChallenge
        case cancelDeleteChallenge
        case onTask
    }

    @Dependency(\.challengeClient) var challengeClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .destination(.presented(.alert(.deleteChallenge))):
                    return .run { send in
                        await send(.confirmDeleteChallenge)
                    }
                case .addChallengeButtonTapped:
                    state.destination = .addChallenge(ChallengeFormFeature.State())
                    return .none
                case .binding:
                    return .none
                case let .challengeUpdated(challenges):
                    state.challenges = challenges
                    return .none
                case .confirmAddChallengeButtonTapped:
                    guard case let .some(.addChallenge(newChallengeFormFeature)) = state.destination
                    else { return .none }

                    let newChallenge = newChallengeFormFeature.wipChallenge
                    state.destination = nil

                    return .run { _ in
                        let _ = await self.challengeClient.add(newChallenge)
                    }
                case .destination:
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case let .deleteChallenge(challenge):
                    state.challengeToDelete = challenge
                    state.destination = .alert(
                        AlertState {
                            TextState("Confirm deletion")
                        } actions: {
                            ButtonState(role: .cancel) {
                                TextState("Never mind")
                            }
                            ButtonState(role: .destructive, action: .deleteChallenge) {
                                TextState("Delete")
                            }
                        } message: {
                            TextState("Are you sure you want to delete this challenge ?")
                        }
                    )
                    return .none
                case .confirmDeleteChallenge:
                    guard let challengeToDelete = state.challengeToDelete else { return .none }
                    state.challenges.removeAll { $0.id == challengeToDelete.id }
                    state.destination = nil
                    state.challengeToDelete = nil
                    return .run { _ in
                        try await self.challengeClient.delete(challengeToDelete.id)
                    }
                case .cancelDeleteChallenge:
                    state.destination = nil
                    state.challengeToDelete = nil
                    return .none
                case .onTask:
                    return .run { send in
                        let challenges = await (try? self.challengeClient.getAll().get()) ?? []
                        await send(.challengeUpdated(challenges))
                    }
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

struct ChallengeView: View {
    @Bindable var store: StoreOf<ChallengeFeature>

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.challenges) { challenge in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(challenge.title)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(challenge.state.rawValue)
                                .font(.caption)
                                .foregroundColor(challenge.stateColor)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(challenge.stateColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Text("\(ChallengeView.dateFormatter.string(from: challenge.startDate)) - \(ChallengeView.dateFormatter.string(from: challenge.endDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(challenge.body)")
                            .font(.footnote)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.send(.deleteChallenge(challenge))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Challenge")
            .toolbar {
                Button {
                    self.store.send(.addChallengeButtonTapped)
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
            item: $store.scope(state: \.destination?.addChallenge, action: \.destination.addChallenge)
        ) { addChallengeStore in
            NavigationStack {
                ChallengeFormView(store: addChallengeStore)
                    .navigationTitle("New challenge")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                store.send(.confirmAddChallengeButtonTapped)
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
        ChallengeView(
            store: Store(initialState: ChallengeFeature.State()) {
                ChallengeFeature()
            }
        )
    }

}
