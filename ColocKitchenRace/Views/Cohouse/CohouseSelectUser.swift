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
    struct State {
        var cohouse: Cohouse
        var selectedUser: CohouseUser
        var newUserName = ""
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case binding(BindingAction<State>)
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
                case .addUserButtonTapped:
                    guard !state.newUserName.isEmpty else { return .none }

                    let newUser = CohouseUser(id: .init(), surname: state.newUserName)
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
