//
//  UserProfileDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct UserProfileDetailFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
    }
    enum Action: Equatable {
        case signOutButtonTapped
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .signOutButtonTapped:
                return .run { _ in
                    self.authentificationClient.signOut()
                }
            }
        }
    }
}

struct UserProfileDetailView: View {
    @Perception.Bindable var store: StoreOf<UserProfileDetailFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("Basic info") {
                    Text(store.userInfo?.firstName ?? "")
                    Text(store.userInfo?.lastName ?? "")
                    Text(store.userInfo?.email ?? "")
                    if let phoneNumber = store.userInfo?.phoneNumber {
                        Text(phoneNumber)
                    }
                }

                Section("Food related") {
                    Text(store.userInfo?.formattedFoodIntolerenceList ?? "")
                }

                //                Section("CKR") {
                //                    Toggle(isOn: $store.wipUser.isSubscribeToNews) {
                //                        Text("Do you want to have news from CKR team ?")
                //                    }
                //                }

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
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileDetailView(
            store: Store(initialState: UserProfileDetailFeature.State()) {
                UserProfileDetailFeature()
            })
    }
}
