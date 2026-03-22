//
//  UsersView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 12/02/2026.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Feature

@Reducer
struct UsersFeature {

    @Reducer
    enum Destination {
        case alert(AlertState<Action.Alert>)
        case roleSheet(RoleSheetFeature)

        @CasePathable
        enum Action {
            case alert(Alert)
            case roleSheet(RoleSheetFeature.Action)

            enum Alert: Equatable {}
        }
    }

    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
        var searchQuery: String = ""
        var searchResults: [User] = []
        var isSearching: Bool = false
        var hasSearched: Bool = false
        var error: String?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case searchQueryChanged(String)
        case performSearch(String)
        case searchCompleted([User])
        case searchFailed(String)
        case userTapped(User)
        case applyRole(User, AdminRole?)
        case roleUpdated(UUID, AdminRole?)
        case roleUpdateFailed(String)
        case destination(PresentationAction<Destination.Action>)
    }

    private enum CancelID {
        case search
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .searchQueryChanged(query):
                state.searchQuery = query

                guard query.count >= 2 else {
                    state.searchResults = []
                    state.hasSearched = false
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }

                state.isSearching = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.performSearch(query))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case let .performSearch(query):
                return .run { send in
                    let result = await userClient.searchUsers(query)
                    switch result {
                    case let .success(users):
                        await send(.searchCompleted(users))
                    case let .failure(error):
                        await send(.searchFailed(error.localizedDescription))
                    }
                }

            case let .searchCompleted(users):
                state.isSearching = false
                state.hasSearched = true
                state.searchResults = users
                return .none

            case let .searchFailed(error):
                state.isSearching = false
                state.hasSearched = true
                state.error = error
                return .none

            case let .userTapped(user):
                state.destination = .roleSheet(
                    RoleSheetFeature.State(user: user, selectedRole: user.effectiveRole)
                )
                return .none

            case let .applyRole(user, role):
                let authUid = user.authId
                let userId = user.id.uuidString

                return .run { send in
                    // 1. Set the custom claim on the Auth token
                    let claimResult = await userClient.setRole(authUid, role)
                    guard case .success = claimResult else {
                        if case let .failure(error) = claimResult {
                            await send(.roleUpdateFailed(error.localizedDescription))
                        }
                        return
                    }

                    // 2. Update the Firestore document to stay in sync
                    let updateResult = await userClient.updateUserRole(userId, role)
                    guard case .success = updateResult else {
                        if case let .failure(error) = updateResult {
                            await send(.roleUpdateFailed("Claim set but Firestore update failed: \(error.localizedDescription)"))
                        }
                        return
                    }

                    await send(.roleUpdated(user.id, role))
                }

            case let .roleUpdated(userId, role):
                if let index = state.searchResults.firstIndex(where: { $0.id == userId }) {
                    state.searchResults[index].role = role
                    state.searchResults[index].isAdmin = role != nil
                }
                return .none

            case let .roleUpdateFailed(error):
                state.destination = .alert(
                    AlertState {
                        TextState("Error")
                    } message: {
                        TextState(error)
                    }
                )
                return .none

            case .destination(.presented(.roleSheet(.confirmTapped))):
                guard case let .roleSheet(sheetState) = state.destination else { return .none }
                let user = sheetState.user
                let role = sheetState.selectedRole
                state.destination = nil
                return .send(.applyRole(user, role))

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

// MARK: - Role Sheet Reducer

@Reducer
struct RoleSheetFeature {
    @ObservableState
    struct State: Equatable {
        let user: User
        var selectedRole: AdminRole?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

// MARK: - Views

struct UsersView: View {
    @Bindable var store: StoreOf<UsersFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !store.hasSearched || store.searchQuery.count < 2 {
                    ContentUnavailableView(
                        "Search for a user",
                        systemImage: "magnifyingglass",
                        description: Text("Type a name or email to find users")
                    )
                } else if store.searchResults.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "person.slash",
                        description: Text("No users match \"\(store.searchQuery)\"")
                    )
                } else {
                    List {
                        ForEach(store.searchResults) { user in
                            Button {
                                store.send(.userTapped(user))
                            } label: {
                                UserRowView(user: user)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .searchable(
                text: $store.searchQuery.sending(\.searchQueryChanged),
                prompt: "Name or email"
            )
        }
        .alert(
            $store.scope(
                state: \.destination?.alert,
                action: \.destination.alert
            )
        )
        .sheet(
            item: $store.scope(
                state: \.destination?.roleSheet,
                action: \.destination.roleSheet
            )
        ) { sheetStore in
            RoleSheetView(store: sheetStore)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Role Sheet View

struct RoleSheetView: View {
    @Bindable var store: StoreOf<RoleSheetFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // User info header
                VStack(spacing: 4) {
                    Text(store.user.fullName.isEmpty ? "Unknown" : store.user.fullName)
                        .font(.title2.bold())
                    if let email = store.user.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                // Role options
                VStack(spacing: 12) {
                    RoleOptionRow(
                        title: "Super Admin",
                        description: "Full access: manage all editions, users, and app settings",
                        systemImage: "shield.checkered",
                        color: .purple,
                        isSelected: store.selectedRole == .superAdmin
                    ) {
                        store.selectedRole = .superAdmin
                    }

                    RoleOptionRow(
                        title: "Edition Admin",
                        description: "Can create and manage special editions only",
                        systemImage: "star.circle",
                        color: .blue,
                        isSelected: store.selectedRole == .editionAdmin
                    ) {
                        store.selectedRole = .editionAdmin
                    }

                    RoleOptionRow(
                        title: "No admin role",
                        description: "Regular user with no admin access",
                        systemImage: "person",
                        color: .gray,
                        isSelected: store.selectedRole == nil
                    ) {
                        store.selectedRole = nil
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Set Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss handled by sheet binding
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        store.send(.confirmTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct RoleOptionRow: View {
    let title: String
    let description: String
    let systemImage: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? color : .secondary)
                    .fixedSize()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - User Row

struct UserRowView: View {
    let user: User

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName.isEmpty ? "Unknown" : user.fullName)
                    .font(.headline)

                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let role = user.effectiveRole {
                Text(role.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        role == .superAdmin ? Color.purple : Color.blue,
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    UsersView(
        store: Store(initialState: UsersFeature.State()) {
            UsersFeature()
        }
    )
}
