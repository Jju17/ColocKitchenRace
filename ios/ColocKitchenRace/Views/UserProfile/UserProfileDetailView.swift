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
        var successMessage: String?
        var isDeleting: Bool = false
        var showDeleteConfirmation: Bool = false
        @Shared(.userInfo) var userInfo
    }
    enum Action {
        case confirmEditUserButtonTapped
        case deleteAccountButtonTapped
        case deleteAccountConfirmed
        case deleteAccountFailed(String)
        case destination(PresentationAction<Destination.Action>)
        case dismissDeleteConfirmation
        case dismissDestinationButtonTapped
        case dismissErrorMessageButtonTapped
        case dismissSuccessMessageButtonTapped
        case editUserButtonTapped
        case signOutButtonTapped
        case signOutFailed(String)
        case _emailVerificationSent(String)
        case _emailChangeFailed(String)
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

                    let wipUser = editState.wipUser
                    let originalEmail = state.userInfo?.email
                    let newEmail = wipUser.email?.trimmingCharacters(in: .whitespaces)
                    let emailChanged = wipUser.isEmailEditable
                        && originalEmail != nil
                        && newEmail != nil
                        && newEmail != originalEmail?.trimmingCharacters(in: .whitespaces)

                    if emailChanged, let newEmail {
                        // Email changed — save other fields with old email, then send verification
                        var userWithOldEmail = wipUser
                        userWithOldEmail.email = originalEmail
                        let savedUser = userWithOldEmail

                        state.destination = nil
                        return .run { send in
                            try await authenticationClient.updateUser(savedUser)
                            try await authenticationClient.sendVerificationEmail(newEmail)
                            await send(._emailVerificationSent(newEmail))
                        } catch: { error, send in
                            Logger.authLog.log(level: .error, "Email change failed: \(error)")
                            await send(._emailChangeFailed(error.localizedDescription))
                        }
                    } else {
                        // Email not changed — save everything normally
                        state.destination = nil
                        return .run { _ in
                            try await authenticationClient.updateUser(wipUser)
                        } catch: { error, _ in
                            Logger.authLog.log(level: .error, "Failed to update user: \(error)")
                        }
                    }
                case .deleteAccountButtonTapped:
                    state.showDeleteConfirmation = true
                    return .none
                case .deleteAccountConfirmed:
                    state.showDeleteConfirmation = false
                    state.isDeleting = true
                    state.errorMessage = nil
                    return .run { send in
                        try await self.authenticationClient.deleteAccount()
                    } catch: { error, send in
                        Logger.authLog.log(level: .error, "Delete account failed: \(error)")
                        await send(.deleteAccountFailed("Failed to delete account. Please try again."))
                    }
                case let .deleteAccountFailed(message):
                    state.isDeleting = false
                    state.errorMessage = message
                    return .none
                case .destination:
                    return .none
                case .dismissDeleteConfirmation:
                    state.showDeleteConfirmation = false
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .dismissErrorMessageButtonTapped:
                    state.errorMessage = nil
                    return .none
                case .dismissSuccessMessageButtonTapped:
                    state.successMessage = nil
                    return .none
                case let ._emailVerificationSent(newEmail):
                    state.successMessage = "A verification link has been sent to \(newEmail). Your email will be updated once you click it."
                    return .none
                case let ._emailChangeFailed(message):
                    state.errorMessage = message
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
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign out")
                    }
                }
            }

            Section {
                Button {
                    self.store.send(.deleteAccountButtonTapped)
                } label: {
                    if store.isDeleting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Deleting account...")
                        }
                    } else {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete account")
                        }
                    }
                }
                .foregroundStyle(Color.red)
                .disabled(store.isDeleting)
                .confirmationDialog(
                    "Delete account",
                    isPresented: Binding(
                        get: { store.showDeleteConfirmation },
                        set: { if !$0 { store.send(.dismissDeleteConfirmation) } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete my account", role: .destructive) {
                        store.send(.deleteAccountConfirmed)
                    }
                    Button("Cancel", role: .cancel) {
                        store.send(.dismissDeleteConfirmation)
                    }
                } message: {
                    Text("This will permanently delete your account, your data, and remove you from your cohouse. This action cannot be undone.")
                }
            } footer: {
                Text("This will permanently delete your account and all associated data.")
                    .font(.caption)
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
        .alert("Email Verification", isPresented: Binding(
            get: { store.successMessage != nil },
            set: { if !$0 { store.send(.dismissSuccessMessageButtonTapped) } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.successMessage ?? "")
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
