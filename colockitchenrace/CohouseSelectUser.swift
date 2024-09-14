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
                state.cohouse.users.append(CohouseUser(id: .init(), surname: state.newUserName))
                return .none
            case .binding:
                return .none
            }
        }
    }
}

struct CohouseSelectUserView: View {
    @Perception.Bindable var store: StoreOf<CohouseSelectUserFeature>

    var body: some View {
        WithPerceptionTracking {
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
}

#Preview {
    CohouseSelectUserView(store: .init(
        initialState: CohouseSelectUserFeature.State(cohouse: Cohouse.mock, selectedUser: Cohouse.mock.users[0])
    ) {
        CohouseSelectUserFeature()
    })
}
