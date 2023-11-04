//
//  UserProfileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct UserProfileFeature: Reducer {
    struct State: Equatable {
        @BindingState var user: User
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
    let store: StoreOf<UserProfileFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
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
                    TextField("Name", text: viewStore.$user.displayName)
                    TextField("Email", text: viewStore.$user.email ?? "")
                    TextField("GSM", text: viewStore.$user.phoneNumber ?? "")
                }

                // TODO: JR: This would be an array of Objects
                Section("Food related") {
                    TextField("Food intolerances", text: viewStore.$user.foodIntolerence)
                }

                Section("CKR") {
                    Toggle(isOn: viewStore.$user.isContactUser) {
                        Text("Are you the contact person ?")
                    }
                    Toggle(isOn: viewStore.$user.isSubscribeToNews) {
                        Text("Do you want to have news from CKR team ?")
                    }
                }

                Section {
                    Button {
                        viewStore.send(.signOutButtonTapped)
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
