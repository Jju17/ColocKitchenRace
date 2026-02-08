//
//  CohouseSelectUser.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 28/07/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohouseSelectUserFeature {

    @ObservableState
    struct State: Equatable {
        var cohouse: Cohouse
        var selectedUser: CohouseUser
        var newUserName = ""
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case binding(BindingAction<State>)
    }

    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
                case .addUserButtonTapped:
                    let trimmedName = state.newUserName.trimmingCharacters(in: .whitespaces)
                    guard !trimmedName.isEmpty else { return .none }
                    guard !state.cohouse.users.contains(where: { $0.surname.lowercased() == trimmedName.lowercased() }) else { return .none }

                    let newUser = CohouseUser(id: uuid(), surname: trimmedName)
                    state.cohouse.users.append(newUser)
                    state.selectedUser = newUser
                    state.newUserName = ""
                    return .none
                case .binding:
                    return .none
            }
        }
    }
}

struct CohouseSelectUserView: View {
    @Bindable var store: StoreOf<CohouseSelectUserFeature>

    var body: some View {
        List {
            Picker("Select yourself", selection: self.$store.selectedUser) {
                ForEach(self.store.cohouse.users, id: \.self) {
                    Text($0.surname)
                }
            }
            .pickerStyle(.inline)
            TextField("Name", text: self.$store.newUserName)
            Button("Add user") {
                store.send(.addUserButtonTapped)
            }
        }
    }
}

#Preview {
    CohouseSelectUserView(store: .init(
        initialState: CohouseSelectUserFeature.State(cohouse: Cohouse.mock, selectedUser: Cohouse.mock.users[0])
    ) {
        CohouseSelectUserFeature()
    })
}
