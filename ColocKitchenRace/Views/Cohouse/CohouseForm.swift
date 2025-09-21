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
        @Shared(.userInfo) var userInfo
        var wipCohouse: Cohouse
        var isNewCohouse: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case assignAdminButtonTapped
        case binding(BindingAction<State>)
        case deleteUsers(atOffset: IndexSet)
        case quitCohouseButtonTapped
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .addUserButtonTapped:
                state.wipCohouse.users.append(CohouseUser(id: UUID()))
                return .none
            case .assignAdminButtonTapped:
                return .none
            case .binding:
                return .none
            case let .deleteUsers(atOffset: indices):

                // Filter out the indexes where users are admins
                let nonAdminIndexes = indices.filter {
                    !state.wipCohouse.users[$0].isAdmin
                }

                // Delete only non-admin users
                for index in nonAdminIndexes.sorted(by: >) {
                    state.wipCohouse.users.remove(at: index)
                }

                // Add a new user automatically if empty
                if state.wipCohouse.users.isEmpty {
                    state.wipCohouse.users.append(CohouseUser(id: UUID(), isAdmin: true))
                }
                return .none
            case .quitCohouseButtonTapped:
                return .run { _ in
                    try await self.cohouseClient.quitCohouse()
                }
            }
        }
    }
}

struct CohouseFormView: View {
    @Bindable var store: StoreOf<CohouseFormFeature>

    var body: some View {
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

                if !store.isNewCohouse && !self.isActualUserIsAdmin() {
                    Section {
                        Button("Quit cohouse") {
                            store.send(.quitCohouseButtonTapped)
                        }
                        .foregroundStyle(.red)
                    }
                }

                //TODO: Handle admin swap
//                if !store.isNewCohouse && self.isActualUserIsAdmin() {
//                    Section {
//                        Button("Assign another admin") {
//                            store.send(.assignAdminButtonTapped)
//                        }
//                        .foregroundStyle(.red)
//                    }
//                }
            }

    }

    func isActualUserIsAdmin() -> Bool {
        let adminUser = store.wipCohouse.users.first { $0.isAdmin }?.userId
        let userInfo = store.userInfo?.id.uuidString
        return adminUser == userInfo
    }


}

#Preview {
    CohouseFormView(
        store: Store(initialState: CohouseFormFeature.State(wipCohouse: .mock, isNewCohouse: true)) {
            CohouseFormFeature()
        })
}
