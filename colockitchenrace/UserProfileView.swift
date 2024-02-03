//
//  UserProfileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct UserProfileFeature {

    @ObservableState
    struct State: Equatable {
        var user: User
    }
    enum Action: BindableAction, Equatable {
        case backButtonTapped
        case binding(BindingAction<State>)
        case signOutButtonTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                return .none
            case .binding(_):
                return .none
            case .signOutButtonTapped:
                return .none
            }
        }
    }
}

struct UserProfileView: View {
    @Perception.Bindable var store: StoreOf<UserProfileFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                HStack {
                    Spacer()
                    Image("Louis")
                        .resizable()
                        .frame(width:100, height: 100)
                    .clipShape(Circle())
                    Spacer()
                }
                
                Section("Basic info") {
                    TextField("Name", text: $store.user.displayName)
                    TextField("Email", text: $store.user.email ?? "")
                    TextField("GSM", text: $store.user.phoneNumber ?? "")
                }

                // TODO: JR: This would be an array of Objects
                Section("Food related") {
                    TextField("Food intolerances", text: $store.user.foodIntolerence)
                }

                Section("CKR") {
                    Toggle(isOn: $store.user.isContactUser) {
                        Text("Are you the contact person ?")
                    }
                    Toggle(isOn: $store.user.isSubscribeToNews) {
                        Text("Do you want to have news from CKR team ?")
                    }
                }

                Section {
                    Button {
                        store.send(.signOutButtonTapped)
                    } label: {
                        Text("Sign out")
                            .foregroundStyle(Color.red)
                    }

                }
            }
            .navigationBarTitle("Profile")
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(
            store: Store(initialState: UserProfileFeature.State(user: .mockUser)) {
            UserProfileFeature()
        })
    }
}
