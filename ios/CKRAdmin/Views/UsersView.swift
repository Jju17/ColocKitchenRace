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

        @CasePathable
        enum Action {
            case alert(Alert)

            enum Alert: Equatable {
                case confirmToggleAdmin(User)
            }
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
        case toggleAdminTapped(User)
        case confirmToggleAdmin(User)
        case adminStatusUpdated(UUID, Bool)
        case adminStatusFailed(String)
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

            case let .toggleAdminTapped(user):
                let newValue = !(user.isAdmin ?? false)
                let actionText = newValue ? "Promote" : "Remove admin from"
                let name = user.fullName.isEmpty ? "this user" : user.fullName

                state.destination = .alert(
                    AlertState {
                        TextState("\(actionText) \(name)?")
                    } actions: {
                        ButtonState(
                            role: newValue ? nil : .destructive,
                            action: .confirmToggleAdmin(user)
                        ) {
                            TextState(newValue ? "Make Admin" : "Remove Admin")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState(
                            newValue
                            ? "\(name) will be able to access CKRAdmin and manage the app."
                            : "\(name) will no longer have admin access."
                        )
                    }
                )
                return .none

            case let .confirmToggleAdmin(user):
                let newValue = !(user.isAdmin ?? false)
                let authUid = user.authId
                let userId = user.id.uuidString

                return .run { send in
                    // 1. Set the custom claim on the Auth token
                    let claimResult = await userClient.setAdminClaim(authUid, newValue)
                    guard case .success = claimResult else {
                        if case let .failure(error) = claimResult {
                            await send(.adminStatusFailed(error.localizedDescription))
                        }
                        return
                    }

                    // 2. Update the Firestore document to stay in sync
                    let updateResult = await userClient.updateUserAdminStatus(userId, newValue)
                    guard case .success = updateResult else {
                        if case let .failure(error) = updateResult {
                            await send(.adminStatusFailed("Claim set but Firestore update failed: \(error.localizedDescription)"))
                        }
                        return
                    }

                    await send(.adminStatusUpdated(user.id, newValue))
                }

            case let .adminStatusUpdated(userId, isAdmin):
                if let index = state.searchResults.firstIndex(where: { $0.id == userId }) {
                    state.searchResults[index].isAdmin = isAdmin
                }
                return .none

            case let .adminStatusFailed(error):
                state.destination = .alert(
                    AlertState {
                        TextState("Error")
                    } message: {
                        TextState(error)
                    }
                )
                return .none

            case .destination(.presented(.alert(.confirmToggleAdmin(let user)))):
                return .send(.confirmToggleAdmin(user))

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
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
                            UserRowView(user: user)
                                .swipeActions(edge: .trailing) {
                                    let isAdmin = user.isAdmin ?? false
                                    Button {
                                        store.send(.toggleAdminTapped(user))
                                    } label: {
                                        Label(
                                            isAdmin ? "Remove Admin" : "Make Admin",
                                            systemImage: isAdmin ? "person.badge.minus" : "person.badge.shield.checkmark"
                                        )
                                    }
                                    .tint(isAdmin ? .red : .green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .searchable(
                text: Binding(
                    get: { store.searchQuery },
                    set: { store.send(.searchQueryChanged($0)) }
                ),
                prompt: "Name or email"
            )
        }
        .alert(
            $store.scope(
                state: \.destination?.alert,
                action: \.destination.alert
            )
        )
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

            if user.isAdmin == true {
                Text("Admin")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
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
