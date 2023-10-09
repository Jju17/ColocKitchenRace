//
//  CohousingFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct CohousingFormFeature: Reducer {
    struct State: Equatable {
        @BindingState var cohousing: Cohousing
    }

    enum Action: BindableAction {
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
    let store: StoreOf<CohousingFormFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Form {
                Section("Localisation") {
                    TextField("Address", text: viewStore.$cohousing.address)
                    TextField("Postcode", text: viewStore.$cohousing.postCode)
                    TextField("City", text: viewStore.$cohousing.city)
                }

                Section("Membres") {
                    ForEach(viewStore.$cohousing.users) { $user in
                        TextField("Name", text: $user.displayName)
                    }
                    .onDelete { indices in
                        viewStore.send(.deleteUsers(atOffset: indices))
                    }

                    Button("Add user") {
                        viewStore.send(.addUserButtonTapped)
                    }
                }

                Section {
                    Picker(selection: viewStore.$cohousing.users, content: {
                        ForEach(viewStore.cohousing.users) {
                            Text($0.displayName).tag($0.isContactUser)
                        }
                    }, label: {
                        Text("Personne de contact")
                    })
                }
            }
            .navigationBarTitle("Zone 88")
        }
    }
}

#Preview {
    CohousingFormView(
        store: Store(initialState: CohousingFormFeature.State(cohousing: .mock)) {
            CohousingFormFeature()
        })
}
