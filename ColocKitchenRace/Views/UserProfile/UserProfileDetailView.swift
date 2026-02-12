//
//  UserProfileDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import os
import SwiftUI

@Reducer
struct UserProfileDetailFeature {

    @Reducer
    enum Destination {
        case editUser(UserProfileFormFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var errorMessage: String?
        @Shared(.userInfo) var userInfo
    }
    enum Action {
        case confirmEditUserButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case dismissErrorMessageButtonTapped
        case editUserButtonTapped
        case signOutButtonTapped
        case signOutFailed(String)
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .confirmEditUserButtonTapped:
                    guard case let .some(.editUser(editState)) = state.destination
                    else { return .none }

                    if let error = UserValidation.validateProfileFields(
                        firstName: editState.wipUser.firstName,
                        lastName: editState.wipUser.lastName,
                        email: editState.wipUser.email
                    ) {
                        state.errorMessage = error
                        return .none
                    }

                    state.destination = nil
                    return .run { _ in
                        try await authenticationClient.updateUser(editState.wipUser)
                    } catch: { error, _ in
                        Logger.authLog.log(level: .error, "Failed to update user: \(error)")
                    }
                case .destination:
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .dismissErrorMessageButtonTapped:
                    state.errorMessage = nil
                    return .none
                case .editUserButtonTapped:
                    state.destination = .editUser(
                        UserProfileFormFeature.State()
                    )
                    return .none
                case .signOutButtonTapped:
                    state.errorMessage = nil
                    return .run { send in
                        try await self.authenticationClient.signOut()
                    } catch: { error, send in
                        Logger.authLog.log(level: .error, "Sign out failed: \(error)")
                        await send(.signOutFailed("Sign out failed. Please try again."))
                    }
                case let .signOutFailed(message):
                    state.errorMessage = message
                    return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension UserProfileDetailFeature.Destination.State: Equatable {}

struct UserProfileDetailView: View {
    @Bindable var store: StoreOf<UserProfileDetailFeature>

    @ViewBuilder
    private var dietaryPreferencesContent: some View {
        if let dietaryPreferences = store.userInfo?.dietaryPreferences, !dietaryPreferences.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(dietaryPreferences.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { preference in
                    dietaryPreferenceTag(preference)
                }
            }
        } else {
            Text("No dietary preferences")
                .foregroundStyle(.secondary)
        }
    }

    private func dietaryPreferenceTag(_ preference: DietaryPreference) -> some View {
        Text("\(preference.icon) \(preference.displayName)")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ckrLavenderLight)
            .foregroundStyle(.black)
            .clipShape(Capsule())
    }

    var body: some View {
        Form {
            Section("Basic info") {
                Text(store.userInfo?.firstName ?? "")
                Text(store.userInfo?.lastName ?? "")
                Text(store.userInfo?.email ?? "")
                if let phoneNumber = store.userInfo?.phoneNumber {
                    Text(phoneNumber)
                }
            }

            Section("Dietary preferences") {
                self.dietaryPreferencesContent
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.editUserButtonTapped)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.dismissErrorMessageButtonTapped) } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(item: $store.scope(state: \.destination?.editUser, action: \.destination.editUser)) { editUserStore in
            NavigationStack {
                UserProfileFormView(store: editUserStore)
                    .navigationTitle("Edit profile")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            let wip = editUserStore.wipUser
                            Button("Confirm") {
                                store.send(.confirmEditUserButtonTapped)
                            }
                            .disabled(
                                UserValidation.validateProfileFields(
                                    firstName: wip.firstName,
                                    lastName: wip.lastName,
                                    email: wip.email
                                ) != nil
                            )
                        }
                    }
            }
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
