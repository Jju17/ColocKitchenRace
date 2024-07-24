//
//  CohouseFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

@Reducer
struct CohouseFormFeature {

    @ObservableState
    struct State {
        var wipCohouse: Cohouse
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case binding(BindingAction<State>)
        case deleteUsers(atOffset: IndexSet)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .addUserButtonTapped:
                state.wipCohouse.users.append(CohouseUser(id: UUID()))
                return .none
            case .binding(_):
                return .none
            case let .deleteUsers(atOffset: indices):
                state.wipCohouse.users.remove(atOffsets: indices)
                if state.wipCohouse.users.isEmpty {
                    state.wipCohouse.users.append(CohouseUser(id: UUID()))
                }
                return .none
            }
        }
    }
}

struct CohouseFormView: View {
    @Perception.Bindable var store: StoreOf<CohouseFormFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    TextField("Cohouse name", text: $store.wipCohouse.name)
                }

                Section("Localisation") {
                    TextField(text: $store.wipCohouse.address.street) { Text("Address") }
                    TextField(text: $store.wipCohouse.address.postalCode) { Text("Postcode") }
                    TextField(text: $store.wipCohouse.address.city) { Text("City") }
                }

                Section("Membres") {
                    ForEach($store.wipCohouse.users) { $user in
                        TextField("Name", text: $user.surname)
                    }
                    .onDelete { indices in
                        store.send(.deleteUsers(atOffset: indices))
                    }

                    Button("Add user") {
                        store.send(.addUserButtonTapped)
                    }
                }
            }
        }
    }
}

#Preview {
    CohouseFormView(
        store: Store(initialState: CohouseFormFeature.State(wipCohouse: .mock)) {
            CohouseFormFeature()
        })
}
