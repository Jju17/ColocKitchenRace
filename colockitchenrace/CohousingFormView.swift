//
//  CohousingFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohousingFormFeature {

    @ObservableState
    struct State: Equatable {
        var cohousing: Cohouse
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
                state.cohousing.users.append(User(id: UUID()))
                return .none
            case .binding(_):
                return .none
            case let .deleteUsers(atOffset: indices):
                state.cohousing.users.remove(atOffsets: indices)
                if state.cohousing.users.isEmpty {
                    state.cohousing.users.append(User(id: UUID()))
                }
                return .none
            }
        }
    }
}

struct CohousingFormView: View {
    @Perception.Bindable var store: StoreOf<CohousingFormFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    TextField("Cohousing name", text: $store.cohousing.name)
                }

                Section("Localisation") {
                    TextField(text: $store.cohousing.address.street) { Text("Address") }
                    TextField(text: $store.cohousing.address.postalCode) { Text("Postcode") }
                    TextField(text: $store.cohousing.address.city) { Text("City") }
                }

                Section("Membres") {
                    ForEach($store.cohousing.users) { $user in
                        TextField("Name", text: $user.firstName)
                    }
                    .onDelete { indices in
                        store.send(.deleteUsers(atOffset: indices))
                    }

                    Button("Add user") {
                        store.send(.addUserButtonTapped)
                    }
                }

                Section {
                    Picker(selection: $store.cohousing.users, content: {
                        ForEach(store.cohousing.users) {
                            Text($0.firstName).tag($0.isContactUser)
                        }
                    }, label: {
                        Text("Contact person")
                    })
                }
            }
        }
    }
}

#Preview {
    CohousingFormView(
        store: Store(initialState: CohousingFormFeature.State(cohousing: .mock)) {
            CohousingFormFeature()
        })
}
