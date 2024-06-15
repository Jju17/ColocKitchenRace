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
                    Text(store.userInfo?.phoneNumber ?? "")
                    Text(store.userInfo?.firstName ?? "")
                }

                // TODO: JR: This would be an array of Objects
                Section("Food related") {
                    Text(store.userInfo?.foodIntolerences.joined(separator: ", ") ?? "")
                }

                Section("CKR") {
//                    Toggle(isOn: $store.userInfo.isContactUser) {
//                        Text("Are you the contact person ?")
//                    }
//                    Toggle(isOn: $store.wipUser.isSubscribeToNews) {
//                        Text("Do you want to have news from CKR team ?")
//                    }
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
