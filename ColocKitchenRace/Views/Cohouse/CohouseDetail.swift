//
//  CohouseDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import os
import SwiftUI
import UIKit

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
        var coverImageData: Data?

        var coverImage: UIImage? {
            coverImageData.flatMap { UIImage(data: $0) }
        }
    }

    enum Action {
        case confirmEditCohouseButtonTapped
        case coverImageLoaded(Data?)
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
                    guard case var .edit(formState) = state.destination
                    else { return .none }

                    var wipCohouse = formState.wipCohouse

                    // If address was changed, require validation
                    if formState.hasAddressChanged {
                        let isAddressAccepted: Bool = {
                            switch formState.addressValidationResult {
                            case .valid, .lowConfidence: return true
                            default: return false
                            }
                        }()

                        guard isAddressAccepted else {
                            formState.creationError = "Please wait for address validation before saving."
                            state.destination = .edit(formState)
                            return .none
                        }
                    }

                    wipCohouse.users.removeAll { user in
                        user.surname.isEmpty && !user.isAdmin
                    }

                    let coverImageData = formState.coverImageData
                    state.destination = nil
                    return .run { [wipCohouse, coverImageData] send in
                        var updatedCohouse = wipCohouse
                        // Upload new cover image if provided
                        if let coverData = coverImageData {
                            let path = try await self.cohouseClient.uploadCoverImage(updatedCohouse.id.uuidString, coverData)
                            updatedCohouse.coverImagePath = path
                        }
                        try await self.cohouseClient.set(id: updatedCohouse.id.uuidString, newCohouse: updatedCohouse)
                        // Use form data directly — no re-download needed
                        if let coverData = coverImageData {
                            await send(.coverImageLoaded(coverData))
                        }
                    } catch: { error, _ in
                        Logger.cohouseLog.log(level: .error, "Failed to save cohouse: \(error)")
                    }
                case .dismissEditCohouseButtonTapped:
                    state.destination = nil
                    return .none
                case let .coverImageLoaded(data):
                    state.coverImageData = data
                    return .none
                case .destination:
                    return .none
                case .editButtonTapped:
                    state.destination = .edit(
                        CohouseFormFeature.State(
                            wipCohouse: state.cohouse,
                            originalAddress: state.cohouse.address
                        )
                    )
                    return .none
                case .refresh:
                    let id = state.cohouse.id.uuidString
                    return .run { send in
                        do {
                            let cohouse = try await cohouseClient.get(id)
                            // Load cover image if path exists
                            if let path = cohouse.coverImagePath {
                                let data = try? await cohouseClient.loadCoverImage(path)
                                await send(.coverImageLoaded(data))
                            } else {
                                await send(.coverImageLoaded(nil))
                            }
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

    private let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    private func cardRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Cover image
                Group {
                    if let coverImage = store.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image("defaultColocBackground")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(height: 150)
                .clipped()
                .clipShape(cardShape)

                // Code
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
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.CKRPurple)
                .clipShape(cardShape)

                // Location
                VStack(alignment: .leading, spacing: 0) {
                    Text("LOCATION")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        cardRow(label: "Address", value: store.cohouse.address.street)
                        Divider().padding(.leading)
                        cardRow(label: "ZIP Code", value: store.cohouse.address.postalCode)
                        Divider().padding(.leading)
                        cardRow(label: "City", value: store.cohouse.address.city)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(cardShape)
                }

                // Members
                VStack(alignment: .leading, spacing: 0) {
                    Text("MEMBERS (\(store.cohouse.users.count))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(store.cohouse.users.enumerated()), id: \.element.id) { index, user in
                            if index > 0 {
                                Divider().padding(.leading)
                            }
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
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(cardShape)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
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
