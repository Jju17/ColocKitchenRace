//
//  NoCohouseView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/02/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NoCohouseFeature {

    @Reducer
    enum Destination {
        case create(CohouseFormFeature)
        case setCohouseUser(CohouseSelectUserFeature)
    }

    @ObservableState
    struct State {
        @Shared(.userInfo) var userInfo
        @Presents var destination: Destination.State?
        var cohouseCode: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmCreateCohouseButtonTapped
        case confirmJoinCohouseButtonTapped
        case createCohouseButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case findExistingCohouseButtonTapped
        case setUserToCohouseFound(Cohouse)
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce {
            state,
            action in
            switch action {
            case .binding:
                return .none
            case .confirmCreateCohouseButtonTapped:
                guard case let .some(.create(cohouseFormFeature)) = state.destination
                else { return .none }

                let newCohouse = cohouseFormFeature.wipCohouse

                guard newCohouse.totalUsers > 0,
                      newCohouse.users.allSatisfy({ $0.surname != "" }),
                      newCohouse.users.first(where: { $0.isAdmin }) != nil
                else { return .none }

                state.destination = nil

                return .run { _ in
                    let _ = try? await self.cohouseClient.add(newCohouse)
                }
            case .confirmJoinCohouseButtonTapped:
                @Shared(.cohouse) var cohouse

                guard case let .some(.setCohouseUser(selectState)) = state.destination
                else { return .none }

                let selectedCohouse = selectState.cohouse
                let selectedUser = selectState.selectedUser

                cohouse = selectedCohouse
                state.destination = nil

                return .run { [selectedUser = selectedUser, cohouseId = selectedCohouse.id.uuidString] _ in
                    try await self.cohouseClient.setUser(selectedUser, cohouseId)
                }
            case .createCohouseButtonTapped:
                guard let userInfo = state.userInfo else { return .none }
                let uuid = UUID()
                guard let code = uuid.uuidString.components(separatedBy: "-").first else { return .none }
                let owner = userInfo.toCohouseUser(isAdmin: true)
                state.destination = .create(
                    CohouseFormFeature.State(
                        wipCohouse: Cohouse(id: uuid, code: code, users: [owner]),
                        isNewCohouse: true
                    )
                )
                return .none
            case .destination:
              return .none
            case .dismissDestinationButtonTapped:
                state.destination = nil
                return .none
            case .findExistingCohouseButtonTapped:
                return .run { [cohouseCode = state.cohouseCode] send in
                    guard let cohouseResult = try? await self.cohouseClient.getByCode(cohouseCode) else { return }

                    switch cohouseResult {
                    case let .success(cohouse):
                        await send(.setUserToCohouseFound(cohouse))
                    case let .failure(error):
                        print(error.localizedDescription)
                    }
                }
            case let .setUserToCohouseFound(cohouse):
                guard let firstUser = cohouse.users.first else { return .none }
                state.destination = .setCohouseUser(
                    CohouseSelectUserFeature.State(cohouse: cohouse, selectedUser: firstUser)
                )
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

}

struct NoCohouseView: View {
    @Perception.Bindable var store: StoreOf<NoCohouseFeature>
    @FocusState var codeIsFocused: Bool

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    HStack(spacing: 50) {
                        Text("Code")
                        TextField(text: $store.cohouseCode) {
                            Text("Code")
                        }
                        .focused($codeIsFocused)
                    }
                    Button("Join existing cohouse") {
                        self.store.send(.findExistingCohouseButtonTapped)
                    }
                }

                Section {
                    Button("Create new cohouse") {
                        store.send(.createCohouseButtonTapped)
                    }
                }
            }
            .navigationTitle("Cohouse")
            .onAppear {
                self.codeIsFocused = true
            }
            .sheet(
              item: $store.scope(state: \.destination?.create, action: \.destination.create)
            ) { createCohouseStore in
              NavigationStack {
                CohouseFormView(store: createCohouseStore)
                  .navigationTitle("New cohouse")
                  .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                      Button("Dismiss") {
                        store.send(.dismissDestinationButtonTapped)
                      }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                      Button("Create") {
                          store.send(.confirmCreateCohouseButtonTapped)
                      }
                    }
                  }
              }
            }
            .sheet(
              item: $store.scope(state: \.destination?.setCohouseUser, action: \.destination.setCohouseUser)
            ) { setCohouseUserStore in
              NavigationStack {
                CohouseSelectUserView(store: setCohouseUserStore)
                  .navigationTitle("Select user")
                  .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                      Button("Dismiss") {
                        store.send(.dismissDestinationButtonTapped)
                      }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                      Button("Select") {
                          store.send(.confirmJoinCohouseButtonTapped)
                      }
                    }
                  }
              }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NoCohouseView(store: .init(initialState: NoCohouseFeature.State(), reducer: {
            NoCohouseFeature()
        }))
    }
}
