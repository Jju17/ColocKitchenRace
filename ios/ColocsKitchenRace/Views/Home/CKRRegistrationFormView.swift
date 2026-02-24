//
//  CKRRegistrationFormView.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 11/02/2026.
//

import ComposableArchitecture
import os
import SwiftUI

// MARK: - Feature

@Reducer
struct CKRRegistrationFormFeature {

    @Reducer
    enum Path {
        case paymentSummary(PaymentSummaryFeature)
    }

    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        var cohouse: Cohouse
        var gameId: String
        var pricePerPersonCents: Int
        var attendingUserIds: Set<String> = []
        var averageAge: Int = 25
        var cohouseType: CohouseType = .mixed
        var errorMessage: String?

        var participantCount: Int { attendingUserIds.count }
        var totalCents: Int { participantCount * pricePerPersonCents }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleUser(CohouseUser.ID)
        case continueToPaymentTapped
        case path(StackActionOf<Path>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case registrationSucceeded
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .toggleUser(userId):
                if state.attendingUserIds.contains(userId.uuidString) {
                    state.attendingUserIds.remove(userId.uuidString)
                } else {
                    state.attendingUserIds.insert(userId.uuidString)
                }
                return .none

            case .continueToPaymentTapped:
                guard !state.attendingUserIds.isEmpty else { return .none }

                state.path.append(.paymentSummary(PaymentSummaryFeature.State(
                    gameId: state.gameId,
                    cohouse: state.cohouse,
                    attendingUserIds: state.attendingUserIds,
                    averageAge: state.averageAge,
                    cohouseType: state.cohouseType,
                    pricePerPersonCents: state.pricePerPersonCents,
                    participantCount: state.participantCount,
                    totalCents: state.totalCents
                )))
                return .none

            case .path(.element(_, action: .paymentSummary(.delegate(.registrationSucceeded)))):
                return .send(.delegate(.registrationSucceeded))

            case .path:
                return .none

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension CKRRegistrationFormFeature.Path.State: Equatable {}

// MARK: - Container View (NavigationStack + path)

/// Wraps the registration form in a NavigationStack with path navigation
/// for the 2-step flow (Step 1: form → Step 2: payment).
struct CKRRegistrationFormContainerView: View {
    @Bindable var store: StoreOf<CKRRegistrationFormFeature>
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            CKRRegistrationFormView(store: store)
                .navigationTitle("CKR Registration")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onDismiss()
                        }
                    }
                }
        } destination: { pathStore in
            switch pathStore.case {
            case let .paymentSummary(summaryStore):
                PaymentSummaryView(store: summaryStore)
                    .navigationTitle("Payment")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Form View (Step 1)

struct CKRRegistrationFormView: View {
    @Bindable var store: StoreOf<CKRRegistrationFormFeature>

    var body: some View {
        Form {
            if let error = store.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("Participants") {
                ForEach(store.cohouse.users) { user in
                    Button {
                        store.send(.toggleUser(user.id))
                    } label: {
                        HStack {
                            Image(systemName: store.attendingUserIds.contains(user.id.uuidString)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(store.attendingUserIds.contains(user.id.uuidString)
                                                 ? Color.ckrLavender
                                                 : .secondary)
                            Text(user.surname)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Section("Infos") {
                HStack {
                    Text("Average age")
                    Spacer()
                    TextField("25", value: $store.averageAge, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                Picker("Cohouse type", selection: $store.cohouseType) {
                    ForEach(CohouseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Pricing") {
                HStack {
                    Text("Price per person")
                    Spacer()
                    Text(PaymentSummaryView.formattedCents(store.pricePerPersonCents))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("\(store.participantCount) participant(s)")
                    Spacer()
                    Text(store.participantCount > 0
                         ? PaymentSummaryView.formattedCents(store.totalCents)
                         : "–")
                        .fontWeight(.semibold)
                }
            }

            Section {
                Text("After validation, you will no longer be able to change the number of participants or the cohouse type.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Important")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.send(.continueToPaymentTapped)
            } label: {
                Text("Continue to payment")
                    .font(.custom("BaksoSapi", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        store.attendingUserIds.isEmpty
                            ? Color.gray
                            : Color.ckrLavender
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(store.attendingUserIds.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    CKRRegistrationFormContainerView(
        store: Store(
            initialState: CKRRegistrationFormFeature.State(
                cohouse: .mock,
                gameId: "preview-game-id",
                pricePerPersonCents: 500
            )
        ) {
            CKRRegistrationFormFeature()
        },
        onDismiss: {}
    )
}
