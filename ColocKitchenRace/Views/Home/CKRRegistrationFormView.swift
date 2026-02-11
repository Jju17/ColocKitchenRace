//
//  CKRRegistrationFormView.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 11/02/2026.
//

import ComposableArchitecture
import os
import SwiftUI

@Reducer
struct CKRRegistrationFormFeature {
    @ObservableState
    struct State: Equatable {
        var cohouse: Cohouse
        var gameId: String
        var attendingUserIds: Set<String> = []
        var averageAge: Int = 25
        var cohouseType: CohouseType = .mixed
        var isSubmitting: Bool = false
        var errorMessage: String?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case toggleUser(CohouseUser.ID)
        case submitButtonTapped
        case registrationSucceeded
        case registrationFailed(String)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case registrationSucceeded
        }
    }

    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .toggleUser(userId):
                if state.attendingUserIds.contains(userId.uuidString) {
                    state.attendingUserIds.remove(userId.uuidString)
                } else {
                    state.attendingUserIds.insert(userId.uuidString)
                }
                return .none

            case .submitButtonTapped:
                guard !state.attendingUserIds.isEmpty else { return .none }

                state.isSubmitting = true
                state.errorMessage = nil

                let gameId = state.gameId
                let cohouseId = state.cohouse.id.uuidString
                let attendingUserIds = Array(state.attendingUserIds)
                let averageAge = state.averageAge
                let cohouseType = state.cohouseType.rawValue

                return .run { send in
                    do {
                        try await ckrClient.registerForGame(
                            gameId,
                            cohouseId,
                            attendingUserIds,
                            averageAge,
                            cohouseType
                        )
                        await send(.registrationSucceeded)
                    } catch {
                        await send(.registrationFailed(error.localizedDescription))
                    }
                }

            case .registrationSucceeded:
                state.isSubmitting = false
                return .send(.delegate(.registrationSucceeded))

            case let .registrationFailed(message):
                state.isSubmitting = false
                state.errorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

struct CKRRegistrationFormView: View {
    @Bindable var store: StoreOf<CKRRegistrationFormFeature>

    var body: some View {
        Form {
            if let error = store.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("Participants") {
                ForEach(store.cohouse.users) { user in
                    Button {
                        store.send(.toggleUser(user.id))
                    } label: {
                        HStack {
                            Image(systemName: store.attendingUserIds.contains(user.id.uuidString)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(store.attendingUserIds.contains(user.id.uuidString)
                                                 ? Color.CKRPurple
                                                 : .secondary)
                            Text(user.surname)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Section("Infos") {
                HStack {
                    Text("Moyenne d'âge")
                    Spacer()
                    TextField("25", value: $store.averageAge, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                Picker("Type de coloc", selection: $store.cohouseType) {
                    ForEach(CohouseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Text("Après validation, tu ne pourras plus modifier le nombre de participants ni le type de coloc.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Important")
            }

            Section("Paiement") {
                Text("Le paiement sera ajouté prochainement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.send(.submitButtonTapped)
            } label: {
                Group {
                    if store.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Valider l'inscription")
                            .font(.custom("BaksoSapi", size: 18))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    store.attendingUserIds.isEmpty || store.isSubmitting
                        ? Color.gray
                        : Color.CKRPurple
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(store.attendingUserIds.isEmpty || store.isSubmitting)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    NavigationStack {
        CKRRegistrationFormView(
            store: Store(
                initialState: CKRRegistrationFormFeature.State(
                    cohouse: .mock,
                    gameId: "preview-game-id"
                )
            ) {
                CKRRegistrationFormFeature()
            }
        )
        .navigationTitle("Inscription CKR")
    }
}
