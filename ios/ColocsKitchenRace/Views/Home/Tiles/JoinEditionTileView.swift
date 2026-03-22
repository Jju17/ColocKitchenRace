//
//  JoinEditionTileView.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 21/03/2026.
//

import ComposableArchitecture
import os
import SwiftUI

// MARK: - Reducer

@Reducer
struct JoinEditionFeature {

    enum CancelID { case join, leave, loadEdition }

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
        var joinCode: String = ""
        var isJoining: Bool = false
        var isLeaving: Bool = false
        var errorMessage: String?
        var successMessage: String?

        /// The active special edition game, fetched after joining.
        var activeEdition: CKRGame?
        var isLoadingEdition: Bool = false

        var hasActiveEdition: Bool {
            userInfo?.activeEditionId != nil
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case joinButtonTapped
        case joinResult(Result<JoinEditionResponse, Error>)
        case leaveButtonTapped
        case leaveResult(Result<Void, Error>)
        case loadActiveEdition
        case activeEditionLoaded(CKRGame?)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case editionChanged
        }
    }

    @Dependency(\.editionClient) var editionClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                // Clear error when user types
                state.errorMessage = nil
                state.successMessage = nil
                return .none

            case .joinButtonTapped:
                let code = state.joinCode.trimmingCharacters(in: .whitespaces).uppercased()
                guard !code.isEmpty else {
                    state.errorMessage = "Enter a code to join"
                    return .none
                }
                state.isJoining = true
                state.errorMessage = nil
                state.successMessage = nil
                return .run { send in
                    do {
                        let response = try await editionClient.joinByCode(code)
                        await send(.joinResult(.success(response)))
                    } catch {
                        await send(.joinResult(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.join, cancelInFlight: true)

            case let .joinResult(.success(response)):
                state.isJoining = false
                state.joinCode = ""
                state.successMessage = "Joined \"\(response.title)\"!"
                return .merge(.send(.loadActiveEdition), .send(.delegate(.editionChanged)))

            case let .joinResult(.failure(error)):
                state.isJoining = false
                state.errorMessage = error.localizedDescription
                return .none

            case .leaveButtonTapped:
                guard let editionId = state.userInfo?.activeEditionId else { return .none }
                state.isLeaving = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        try await editionClient.leave(editionId)
                        await send(.leaveResult(.success(())))
                    } catch {
                        await send(.leaveResult(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.leave, cancelInFlight: true)

            case .leaveResult(.success):
                state.isLeaving = false
                state.activeEdition = nil
                state.successMessage = nil
                return .send(.delegate(.editionChanged))

            case let .leaveResult(.failure(error)):
                state.isLeaving = false
                state.errorMessage = error.localizedDescription
                return .none

            case .loadActiveEdition:
                guard let editionId = state.userInfo?.activeEditionId else {
                    state.activeEdition = nil
                    return .none
                }
                state.isLoadingEdition = true
                return .run { send in
                    let game = try? await editionClient.getEdition(editionId)
                    await send(.activeEditionLoaded(game))
                }
                .cancellable(id: CancelID.loadEdition, cancelInFlight: true)

            case let .activeEditionLoaded(game):
                state.isLoadingEdition = false
                state.activeEdition = game
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

struct JoinEditionTileView: View {
    @Bindable var store: StoreOf<JoinEditionFeature>

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.ckrCoral)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                if store.hasActiveEdition {
                    activeEditionContent
                } else {
                    joinCodeContent
                }
            }
            .padding()
        }
    }

    // MARK: - Active Edition (already joined)

    private var activeEditionContent: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Edition")
                        .font(.custom("BaksoSapi", size: 16))
                        .fontWeight(.light)
                        .textCase(.uppercase)
                    Text(store.activeEdition?.title ?? (store.isLoadingEdition ? "Loading…" : "Edition"))
                        .font(.custom("BaksoSapi", size: 24))
                        .fontWeight(.heavy)
                }
                Spacer()
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
            }
            .foregroundStyle(.white)

            if let edition = store.activeEdition {
                VStack(spacing: 6) {
                    if let date = edition.nextGameDate as Date? {
                        HStack {
                            Image(systemName: "calendar")
                            Text(date.formatted(date: .long, time: .shortened))
                            Spacer()
                        }
                        .font(.custom("BaksoSapi", size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                    }

                    if edition.isRegistrationOpen {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Registrations open!")
                            Spacer()
                        }
                        .font(.custom("BaksoSapi", size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }

            if store.isLoadingEdition {
                ProgressView()
                    .tint(.white)
            }

            Button {
                store.send(.leaveButtonTapped)
            } label: {
                HStack {
                    if store.isLeaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Leave edition")
                            .font(.custom("BaksoSapi", size: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(.white)
            .disabled(store.isLeaving)

            if let error = store.errorMessage {
                Text(error)
                    .font(.custom("BaksoSapi", size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Join Code Entry

    private var joinCodeContent: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Special Edition")
                    .font(.custom("BaksoSapi", size: 26))
                    .fontWeight(.heavy)
                Spacer()
            }
            .foregroundStyle(.white)

            Text("Enter a code to join a private edition")
                .font(.custom("BaksoSapi", size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                TextField("CODE", text: $store.joinCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.custom("BaksoSapi", size: 18))
                    .frame(maxWidth: .infinity)

                Button {
                    store.send(.joinButtonTapped)
                } label: {
                    if store.isJoining {
                        ProgressView()
                            .tint(.ckrCoral)
                    } else {
                        Text("Join")
                            .font(.custom("BaksoSapi", size: 18))
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.white)
                .foregroundStyle(Color.ckrCoral)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(store.isJoining)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.custom("BaksoSapi", size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let success = store.successMessage {
                Text(success)
                    .font(.custom("BaksoSapi", size: 13))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("No edition") {
    JoinEditionTileView(
        store: Store(initialState: JoinEditionFeature.State()) {
            JoinEditionFeature()
        }
    )
    .padding()
}
