//
//  PaymentSummaryView.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 12/02/2026.
//

import ComposableArchitecture
import os
import SwiftUI

// MARK: - Feature

@Reducer
struct PaymentSummaryFeature {
    @ObservableState
    struct State: Equatable {
        // Data from Step 1
        var gameId: String
        var cohouse: Cohouse
        var attendingUserIds: Set<String>
        var averageAge: Int
        var cohouseType: CohouseType
        var pricePerPersonCents: Int
        var participantCount: Int
        var totalCents: Int

        // Payment state
        var isCreatingPaymentIntent: Bool = false
        var paymentIntentClientSecret: String?
        var customerId: String?
        var ephemeralKeySecret: String?
        var paymentIntentId: String?
        var isPaymentInProgress: Bool = false
        var isConfirming: Bool = false
        var errorMessage: String?

        var paymentSheetReady: Bool {
            paymentIntentClientSecret != nil
                && customerId != nil
                && ephemeralKeySecret != nil
        }

        var canRetryConfirmation: Bool {
            paymentIntentId != nil && errorMessage != nil && !isConfirming
        }
    }

    enum Action: Equatable {
        case onAppear
        case _paymentIntentCreated(PaymentIntentResult)
        case _paymentIntentFailed(String)
        case paymentButtonTapped
        case paymentCompleted(PaymentResult)
        case _confirmationSucceeded
        case _confirmationFailed(String)
        case retryConfirmationTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case registrationSucceeded
        }
    }

    enum PaymentResult: Equatable {
        case completed
        case canceled
        case failed(String)
    }

    @Dependency(\.stripeClient) var stripeClient
    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isCreatingPaymentIntent, !state.paymentSheetReady else {
                    return .none
                }
                state.isCreatingPaymentIntent = true
                state.errorMessage = nil

                let gameId = state.gameId
                let cohouseId = state.cohouse.id.uuidString
                let totalCents = state.totalCents
                let participantCount = state.participantCount
                let attendingUserIds = Array(state.attendingUserIds)
                let averageAge = state.averageAge
                let cohouseType = state.cohouseType.rawValue

                return .run { send in
                    do {
                        let result = try await stripeClient.reserveAndCreatePayment(
                            gameId, cohouseId, totalCents, participantCount,
                            attendingUserIds, averageAge, cohouseType
                        )
                        await send(._paymentIntentCreated(result))
                    } catch {
                        Logger.paymentLog.error("Failed to reserve spot: \(error.localizedDescription)")
                        await send(._paymentIntentFailed(error.localizedDescription))
                    }
                }

            case let ._paymentIntentCreated(result):
                state.isCreatingPaymentIntent = false
                state.paymentIntentClientSecret = result.clientSecret
                state.customerId = result.customerId
                state.ephemeralKeySecret = result.ephemeralKeySecret
                state.paymentIntentId = result.paymentIntentId
                return .none

            case let ._paymentIntentFailed(message):
                state.isCreatingPaymentIntent = false
                state.errorMessage = message
                return .none

            case .paymentButtonTapped:
                state.isPaymentInProgress = true
                state.errorMessage = nil
                return .none  // View layer presents Stripe PaymentSheet

            case let .paymentCompleted(result):
                state.isPaymentInProgress = false
                switch result {
                case .completed:
                    return self.performConfirmation(state: &state)
                case .canceled:
                    return .none
                case let .failed(message):
                    state.errorMessage = message
                    return .none
                }

            case ._confirmationSucceeded:
                state.isConfirming = false

                // Update local game state to reflect the confirmed registration
                let cohouseId = state.cohouse.id.uuidString
                let count = state.participantCount
                @Shared(.ckrGame) var ckrGame
                $ckrGame.withLock { game in
                    if game != nil {
                        game!.cohouseIDs.append(cohouseId)
                        game!.totalRegisteredParticipants += count
                    }
                }

                return .send(.delegate(.registrationSucceeded))

            case let ._confirmationFailed(message):
                state.isConfirming = false
                state.errorMessage = "Payment succeeded but confirmation failed: \(message). Please try again."
                return .none

            case .retryConfirmationTapped:
                guard state.paymentIntentId != nil else { return .none }
                return self.performConfirmation(state: &state)

            case .delegate:
                return .none
            }
        }
    }

    private func performConfirmation(state: inout State) -> Effect<Action> {
        state.isConfirming = true
        state.errorMessage = nil

        let gameId = state.gameId
        let cohouseId = state.cohouse.id.uuidString
        let paymentIntentId = state.paymentIntentId!

        return .run { send in
            do {
                try await ckrClient.confirmRegistration(
                    gameId, cohouseId, paymentIntentId
                )
                await send(._confirmationSucceeded)
            } catch {
                Logger.paymentLog.error("Confirmation failed after payment: \(error.localizedDescription)")
                await send(._confirmationFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - View

struct PaymentSummaryView: View {
    @Bindable var store: StoreOf<PaymentSummaryFeature>

    var body: some View {
        Form {
            if let error = store.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section("Order summary") {
                HStack {
                    Text("Participants")
                    Spacer()
                    Text("\(store.participantCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Price per person")
                    Spacer()
                    Text(Self.formattedCents(store.pricePerPersonCents))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text(Self.formattedCents(store.totalCents))
                        .fontWeight(.bold)
                }
            }

            if store.canRetryConfirmation {
                Section {
                    Button("Retry confirmation") {
                        store.send(.retryConfirmationTapped)
                    }
                    .foregroundStyle(.ckrLavender)
                }
            }

            Section {
                Text("Payment is processed securely via Stripe. Your card details are never stored on our servers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.send(.paymentButtonTapped)
            } label: {
                Group {
                    if store.isCreatingPaymentIntent || store.isConfirming {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Pay \(Self.formattedCents(store.totalCents))")
                            .font(.custom("BaksoSapi", size: 18))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    store.paymentSheetReady && !store.isPaymentInProgress && !store.isConfirming
                        ? Color.ckrLavender
                        : Color.gray
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!store.paymentSheetReady || store.isPaymentInProgress || store.isConfirming)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .paymentSheet(
            isPresented: store.isPaymentInProgress,
            clientSecret: store.paymentIntentClientSecret,
            customerId: store.customerId,
            ephemeralKeySecret: store.ephemeralKeySecret,
            onCompletion: { result in
                store.send(.paymentCompleted(result))
            }
        )
    }

    // MARK: - Helpers

    static func formattedCents(_ cents: Int) -> String {
        let euros = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_BE")
        return formatter.string(from: NSNumber(value: euros)) ?? "\(euros) €"
    }
}

#Preview {
    NavigationStack {
        PaymentSummaryView(
            store: Store(
                initialState: PaymentSummaryFeature.State(
                    gameId: "preview-game",
                    cohouse: .mock,
                    attendingUserIds: ["user-1", "user-2", "user-3"],
                    averageAge: 25,
                    cohouseType: .mixed,
                    pricePerPersonCents: 500,
                    participantCount: 3,
                    totalCents: 1500
                )
            ) {
                PaymentSummaryFeature()
            }
        )
        .navigationTitle("Payment")
    }
}
