//
//  CohouseDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import os
import SwiftUI

@Reducer
struct CohouseDetailFeature {

    @Reducer
    enum Destination {
        case edit(CohouseFormFeature)
        case alert(AlertState<Action.Alert>)

        enum Action {
            case edit(CohouseFormFeature.Action)
            case alert(Alert)

            enum Alert: Equatable {
                case okButtonTapped
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        @Shared var cohouse: Cohouse
        @Shared(.userInfo) var userInfo
        @Presents var destination: Destination.State?
    }

    enum Action {
        case confirmEditCohouseButtonTapped
        case dismissEditCohouseButtonTapped
        case editButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case refresh
        case userWasRemovedFromCohouse
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .destination(.presented(.alert(.okButtonTapped))):
                    @Shared(.cohouse) var currentCohouse
                    $currentCohouse.withLock { $0 = nil }
                    return .none
                case .confirmEditCohouseButtonTapped:
                    guard var wipCohouse = state.destination?.edit?.wipCohouse
                    else { return .none }

                    wipCohouse.users.removeAll { user in
                        user.surname.isEmpty && !user.isAdmin
                    }

                    state.destination = nil
                    return .run { [wipCohouse] _ in
                        try await self.cohouseClient.set(id: wipCohouse.id.uuidString, newCohouse: wipCohouse)
                    } catch: { error, _ in
                        Logger.cohouseLog.log(level: .error, "Failed to save cohouse: \(error)")
                    }
                case .dismissEditCohouseButtonTapped:
                    state.destination = nil
                    return .none
                case .destination:
                    return .none
                case .editButtonTapped:
                    state.destination = .edit(
                        CohouseFormFeature.State(wipCohouse: state.cohouse)
                    )
                    return .none
                case .refresh:
                    let id = state.cohouse.id.uuidString
                    return .run { send in
                        do {
                            _ = try await cohouseClient.get(id)
                        } catch let error as CohouseClientError {
                            switch error {
                                case .userNotInCohouse:
                                    await send(.userWasRemovedFromCohouse)
                                default:
                                    Logger.cohouseLog.log(level: .error, "Refresh error: \(error)")
                            }
                        } catch {
                            Logger.cohouseLog.log(level: .error, "Unknown refresh error: \(error)")
                        }
                    }
                case .userWasRemovedFromCohouse:
                    state.destination = .alert(
                        AlertState {
                            TextState("Cohouse updated")
                        } actions: {
                            ButtonState(role: .none, action: .okButtonTapped) {
                                TextState("OK")
                            }
                        } message: {
                            TextState("You have been removed from this cohouse by admin user.")
                        }
                    )
                    return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension CohouseDetailFeature.Destination.State: Equatable {}

struct CohouseDetailView: View {
    @Bindable var store: StoreOf<CohouseDetailFeature>
    @State private var codeCopied = false

    var body: some View {
        Form {
            Section("") {
                Image("defaultColocBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            Section("") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Code :")
                        Text(store.cohouse.code)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = store.cohouse.code
                            codeCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                codeCopied = false
                            }
                        } label: {
                            Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.custom("BaksoSapi", size: 20))
                    .fontWeight(.semibold)
                    Text(codeCopied ? "Copied!" : "Share this code with your cohouse buddies")
                        .font(.custom("BaksoSapi", size: 12))
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.CKRPurple)

            Section("LOCATION") {
                LabeledContent("Address", value: store.cohouse.address.street)
                LabeledContent("ZIP Code", value: store.cohouse.address.postalCode)
                LabeledContent("City", value: store.cohouse.address.city)
            }

            Section("MEMBERS (\(store.cohouse.users.count))") {
                ForEach(store.cohouse.users) { user in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.surname)
                            if user.isAdmin {
                                Text("Admin")
                                    .foregroundStyle(.gray)
                                    .font(.footnote)
                            }
                        }
                        Spacer()
                        if let mainUserId = self.store.userInfo?.id.uuidString,
                            user.userId == mainUserId {
                            Text("Me")
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .navigationBarTitle(store.cohouse.name)
        .refreshable {
            await store.send(.refresh).finish()
        }
        .task {
            await store.send(.refresh).finish()
        }
        .toolbar {
            if store.cohouse.isAdmin(id: store.userInfo?.id) {
                Button {
                    store.send(.editButtonTapped)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .alert(
            $store.scope(
                state: \.destination?.alert,
                action: \.destination.alert
            )
        )
        .sheet(
            item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
        ) { editCohouseStore in
            NavigationStack {
                CohouseFormView(store: editCohouseStore)
                    .navigationTitle("Edit cohouse")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissEditCohouseButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Confirm") {
                                store.send(.confirmEditCohouseButtonTapped)
                            }
                        }
                    }
            }
        }

    }
}

#Preview {
    NavigationStack {
        CohouseDetailView(
            store: Store(
                initialState: CohouseDetailFeature.State(
                    cohouse: Shared(value: .mock)
                )
            ) {
                CohouseDetailFeature()
            }
        )
    }
}
