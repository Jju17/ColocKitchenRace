//
//  NoCohouseView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/02/2024.
//

import ComposableArchitecture
import os
import SwiftUI

@Reducer
struct NoCohouseFeature {

    @Reducer
    enum Destination {
        case create(CohouseFormFeature)
        case setCohouseUser(CohouseSelectUserFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
        @Presents var destination: Destination.State?
        var cohouseCode: String = ""
        var errorMessage: String?
        var isCreating: Bool = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmCreateCohouseButtonTapped
        case confirmJoinCohouseButtonTapped
        case createCohouseButtonTapped
        case creationCompleted
        case creationFailed(String)
        case destination(PresentationAction<Destination.Action>)
        case dismissDestinationButtonTapped
        case findExistingCohouseButtonTapped
        case cohouseLookupFailed(String)
        case setUserToCohouseFound(Cohouse)
    }

    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.storageClient) var storageClient
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                case .confirmCreateCohouseButtonTapped:
                    guard case var .create(formState) = state.destination
                    else { return .none }

                    let newCohouse = formState.wipCohouse
                    let addressValidationResult = formState.addressValidationResult
                    let idCardImageData = formState.idCardImageData

                    // Basic form validation
                    guard newCohouse.totalUsers > 0,
                          newCohouse.users.allSatisfy({ $0.surname != "" }),
                          newCohouse.users.first(where: { $0.isAdmin }) != nil
                    else {
                        formState.creationError = "Please fill in all member names."
                        state.destination = .create(formState)
                        return .none
                    }

                    // Address must have been validated (valid or lowConfidence accepted)
                    let isAddressAccepted: Bool = {
                        switch addressValidationResult {
                        case .valid, .lowConfidence: return true
                        default: return false
                        }
                    }()

                    guard isAddressAccepted else {
                        formState.creationError = "Please validate your address before creating the cohouse."
                        state.destination = .create(formState)
                        return .none
                    }

                    // ID card is required
                    guard let idCardData = idCardImageData else {
                        formState.creationError = "Please take a photo of your ID card."
                        state.destination = .create(formState)
                        return .none
                    }

                    state.isCreating = true

                    return .run { [newCohouse, idCardData] send in
                        do {
                            // 1. Check for duplicate
                            let duplicateResult = try await self.cohouseClient.checkDuplicate(
                                newCohouse.name,
                                newCohouse.address
                            )

                            switch duplicateResult {
                            case .duplicateName:
                                await send(.creationFailed("A cohouse with this name already exists."))
                                return
                            case .duplicateAddress:
                                await send(.creationFailed("A cohouse at this address already exists."))
                                return
                            case .noDuplicate:
                                break
                            }

                            // 2. Create the cohouse
                            try await self.cohouseClient.add(newCohouse)

                            // 3. Upload ID card
                            let storagePath = "cohouses/\(newCohouse.id.uuidString)/id_card.jpg"
                            _ = try await self.storageClient.uploadImage(idCardData, storagePath)

                            await send(.creationCompleted)
                        } catch {
                            Logger.cohouseLog.log(level: .error, "Failed to create cohouse: \(error)")
                            await send(.creationFailed("An error occurred. Please try again."))
                        }
                    }
                case .creationCompleted:
                    state.isCreating = false
                    state.destination = nil
                    return .none
                case let .creationFailed(message):
                    state.isCreating = false
                    if case var .create(formState) = state.destination {
                        formState.creationError = message
                        state.destination = .create(formState)
                    }
                    return .none
                case .confirmJoinCohouseButtonTapped:
                    @Shared(.cohouse) var cohouse

                    guard case let .some(.setCohouseUser(selectState)) = state.destination
                    else { return .none }

                    let selectedCohouse = selectState.cohouse
                    let selectedUser = selectState.selectedUser

                    $cohouse.withLock { $0 = selectedCohouse }
                    state.destination = nil

                    return .run { [selectedUser = selectedUser, cohouseId = selectedCohouse.id.uuidString] _ in
                        try await self.cohouseClient.setUser(selectedUser, cohouseId)
                    }
                case .createCohouseButtonTapped:
                    guard let userInfo = state.userInfo else { return .none }
                    let newId = uuid()
                    guard let code = newId.uuidString.components(separatedBy: "-").first else { return .none }
                    let ownerUUID = uuid()
                    let owner = userInfo.toCohouseUser(cohouseUserId: ownerUUID, isAdmin: true)
                    state.destination = .create(
                        CohouseFormFeature.State(
                            wipCohouse: Cohouse(id: newId, code: code, users: [owner]),
                            isNewCohouse: true
                        )
                    )
                    return .none
                case .destination:
                    return .none
                case .dismissDestinationButtonTapped:
                    state.destination = nil
                    return .none
                case .findExistingCohouseButtonTapped:
                    let code = state.cohouseCode.trimmingCharacters(in: .whitespaces)
                    state.errorMessage = nil
                    guard !code.isEmpty else {
                        state.errorMessage = "Please enter a cohouse code."
                        return .none
                    }
                    return .run { send in
                        do {
                            let cohouse = try await self.cohouseClient.getByCode(code)
                            await send(.setUserToCohouseFound(cohouse))
                        } catch {
                            if let cohouseError = error as? CohouseClientError {
                                switch cohouseError {
                                case .cohouseNotFound:
                                    Logger.cohouseLog.log(level: .info, "Cohouse not found for code \(code)")
                                    await send(.cohouseLookupFailed("No cohouse found with code \"\(code)\"."))
                                default:
                                    Logger.cohouseLog.log(level: .error, "Cohouse lookup failed: \(cohouseError)")
                                    await send(.cohouseLookupFailed("An error occurred. Please try again."))
                                }
                            } else {
                                Logger.cohouseLog.log(level: .error, "Unknown error during cohouse lookup: \(error)")
                                await send(.cohouseLookupFailed("An error occurred. Please try again."))
                            }
                        }
                    }
                case let .cohouseLookupFailed(message):
                    state.errorMessage = message
                    return .none
                case let .setUserToCohouseFound(cohouse):
                    guard let firstUser = cohouse.users.first else { return .none }

                    if cohouse.users.contains(where: { $0.userId == state.userInfo?.id.uuidString }) {
                        @Shared(.cohouse) var actualCohouse
                        $actualCohouse.withLock { $0 = cohouse }
                        state.destination = nil
                        return .none
                    }

                    state.destination = .setCohouseUser(
                        CohouseSelectUserFeature.State(cohouse: cohouse, selectedUser: firstUser)
                    )
                    return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

}

extension NoCohouseFeature.Destination.State: Equatable {}

struct NoCohouseView: View {
    @Bindable var store: StoreOf<NoCohouseFeature>
    @FocusState var codeIsFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: 50) {
                    Text("Code")
                    TextField(text: $store.cohouseCode) {
                        Text("Code")
                    }
                    .focused($codeIsFocused)
                }
                Button("Join existing cohouse") {
                    self.store.send(.findExistingCohouseButtonTapped)
                }

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Create new cohouse") {
                    store.send(.createCohouseButtonTapped)
                }
            }
        }
        .navigationTitle("Cohouse")
        .onAppear {
            self.codeIsFocused = true
        }
        .sheet(
            item: $store.scope(state: \.destination?.create, action: \.destination.create)
        ) { createCohouseStore in
            NavigationStack {
                CohouseFormView(store: createCohouseStore)
                    .navigationTitle("New cohouse")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if store.isCreating {
                                ProgressView()
                            } else {
                                Button("Create") {
                                    store.send(.confirmCreateCohouseButtonTapped)
                                }
                            }
                        }
                    }
            }
        }
        .sheet(
            item: $store.scope(state: \.destination?.setCohouseUser, action: \.destination.setCohouseUser)
        ) { setCohouseUserStore in
            NavigationStack {
                CohouseSelectUserView(store: setCohouseUserStore)
                    .navigationTitle("Select user")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                store.send(.dismissDestinationButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Select") {
                                store.send(.confirmJoinCohouseButtonTapped)
                            }
                        }
                    }
            }
        }

    }
}

#Preview {
    NavigationStack {
        NoCohouseView(store: .init(initialState: NoCohouseFeature.State(), reducer: {
            NoCohouseFeature()
        }))
    }
}
