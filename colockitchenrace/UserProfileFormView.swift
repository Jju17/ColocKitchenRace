//
//  UserProfileFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct UserProfileFormFeature {

    @ObservableState
    struct State: Equatable {
        var wipUser: User = .emptyUser
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppearTriggered
        case signOutButtonTapped
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppearTriggered:
                @Shared(.userInfo) var user
                guard let user = user else { return .none }
                state.wipUser = user
                return .none
            case .signOutButtonTapped:
                return .run { _ in
                do {
                    try await self.authentificationClient.signOut()
                }
                catch { print("already logged out") }
                }
            }
        }
    }
}

struct UserProfileFormView: View {
    @Perception.Bindable var store: StoreOf<UserProfileFormFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("Basic info") {
                    TextField("First name", text: $store.wipUser.firstName)
                    TextField("Last name", text: $store.wipUser.lastName)
                    TextField("Email", text: $store.wipUser.email ?? "")
                    TextField("GSM", text: $store.wipUser.phoneNumber ?? "")
                }

                // TODO: JR: This would be an array of Objects
//                Section("Food related") {
//                    TextField("Food intolerances", text: $store.wipUser.foodIntolerences)
//                }

                Section("CKR") {
                    Toggle(isOn: $store.wipUser.isSubscribeToNews) {
                        Text("Do you want to have news from CKR team ?")
                    }
                }

                Section {
                    Button {
                        self.store.send(.signOutButtonTapped)
                    } label: {
                        Text("Sign out")
                            .foregroundStyle(Color.red)
                    }

                }
            }
            .navigationBarTitle("Profile")
            .onAppear { store.send(.onAppearTriggered) }
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileFormView(
            store: Store(initialState: UserProfileFormFeature.State()) {
                UserProfileFormFeature()
            }
        )
    }
}
