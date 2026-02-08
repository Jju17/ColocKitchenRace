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
        @Shared(.userInfo) var userInfo
        var wipUser: User = .emptyUser

        init() {
            if let user = userInfo {
                wipUser = user
            }
        }

        init(wipUser: User) {
            self.wipUser = wipUser
        }
    }
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppearTriggered
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                case .onAppearTriggered:
                    if let user = state.userInfo {
                        state.wipUser = user
                    }
                    return .none
            }
        }
    }
}

struct UserProfileFormView: View {
    @Bindable var store: StoreOf<UserProfileFormFeature>

    var body: some View {
        Form {
            Section("Basic info") {
                TextField("First name", text: $store.wipUser.firstName)
                TextField("Last name", text: $store.wipUser.lastName)
                TextField("Email", text: $store.wipUser.email ?? "")
                TextField("GSM", text: $store.wipUser.phoneNumber ?? "")
            }

            Section("Dietary preferences") {
                ForEach(DietaryPreference.allCases) { preference in
                    Toggle(isOn: Binding(
                        get: { store.wipUser.dietaryPreferences.contains(preference) },
                        set: { isSelected in
                            if isSelected {
                                store.wipUser.dietaryPreferences.insert(preference)
                            } else {
                                store.wipUser.dietaryPreferences.remove(preference)
                            }
                        }
                    )) {
                        HStack {
                            Text(preference.icon)
                            Text(preference.displayName)
                        }
                    }
                }
            }

            Section("CKR") {
                Toggle(isOn: $store.wipUser.isSubscribeToNews) {
                    Text("Do you want to have news from CKR team ?")
                }
            }
        }
        .navigationBarTitle("Profile")
        .onAppear { store.send(.onAppearTriggered) }

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
