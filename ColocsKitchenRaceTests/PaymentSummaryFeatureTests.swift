//
//  PaymentSummaryFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 12/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct PaymentSummaryFeatureTests {

    private func makeState() -> PaymentSummaryFeature.State {
        PaymentSummaryFeature.State(
            gameId: "test-game",
            cohouse: .mock,
            attendingUserIds: ["user-1", "user-2"],
            averageAge: 25,
            cohouseType: .mixed,
            pricePerPersonCents: 500,
            participantCount: 2,
            totalCents: 1000
        )
    }

    // MARK: - Payment Intent Creation

    @Test("onAppear creates payment intent")
    func onAppearCreatesPaymentIntent() async {
        var createCalled = false

        let store = TestStore(initialState: makeState()) {
            PaymentSummaryFeature()
        } withDependencies: {
            $0.stripeClient.createPaymentIntent = { _, _, _, _ in
                createCalled = true
                return PaymentIntentResult(
                    clientSecret: "pi_secret",
                    customerId: "cus_test",
                    ephemeralKeySecret: "ek_test",
                    paymentIntentId: "pi_test"
                )
            }
        }

        await store.send(.onAppear) {
            $0.isCreatingPaymentIntent = true
        }

        await store.receive(\._paymentIntentCreated) {
            $0.isCreatingPaymentIntent = false
            $0.paymentIntentClientSecret = "pi_secret"
            $0.customerId = "cus_test"
            $0.ephemeralKeySecret = "ek_test"
            $0.paymentIntentId = "pi_test"
        }

        #expect(createCalled)
    }

    @Test("onAppear handles payment intent creation failure")
    func onAppearPaymentIntentFailed() async {
        let store = TestStore(initialState: makeState()) {
            PaymentSummaryFeature()
        } withDependencies: {
            $0.stripeClient.createPaymentIntent = { _, _, _, _ in
                throw StripeError.paymentIntentCreationFailed("Network error")
            }
        }

        await store.send(.onAppear) {
            $0.isCreatingPaymentIntent = true
        }

        await store.receive(\._paymentIntentFailed) {
            $0.isCreatingPaymentIntent = false
            $0.errorMessage = StripeError.paymentIntentCreationFailed("Network error").localizedDescription
        }
    }

    @Test("onAppear does nothing when already creating")
    func onAppearAlreadyCreating() async {
        var state = makeState()
        state.isCreatingPaymentIntent = true

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        }

        await store.send(.onAppear)
    }

    @Test("onAppear does nothing when payment sheet already ready")
    func onAppearAlreadyReady() async {
        var state = makeState()
        state.paymentIntentClientSecret = "pi_secret"
        state.customerId = "cus_test"
        state.ephemeralKeySecret = "ek_test"

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        }

        await store.send(.onAppear)
    }

    // MARK: - Payment Button

    @Test("paymentButtonTapped sets isPaymentInProgress")
    func paymentButtonTapped() async {
        let store = TestStore(initialState: makeState()) {
            PaymentSummaryFeature()
        }

        await store.send(.paymentButtonTapped) {
            $0.isPaymentInProgress = true
        }
    }

    // MARK: - Payment Completed

    @Test("payment completed triggers registration and delegates success")
    func paymentCompletedRegisters() async {
        var state = makeState()
        state.paymentIntentId = "pi_test"

        var registerCalled = false

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        } withDependencies: {
            $0.ckrClient.registerForGame = { _, _, _, _, _, _ in
                registerCalled = true
            }
        }

        await store.send(.paymentCompleted(.completed)) {
            $0.isRegistering = true
        }

        await store.receive(\._registrationSucceeded) {
            $0.isRegistering = false
        }

        await store.receive(\.delegate.registrationSucceeded)

        #expect(registerCalled)
    }

    @Test("payment canceled does nothing")
    func paymentCanceled() async {
        let store = TestStore(initialState: makeState()) {
            PaymentSummaryFeature()
        }

        await store.send(.paymentCompleted(.canceled))
    }

    @Test("payment failed shows error")
    func paymentFailed() async {
        let store = TestStore(initialState: makeState()) {
            PaymentSummaryFeature()
        }

        await store.send(.paymentCompleted(.failed("Card declined"))) {
            $0.errorMessage = "Card declined"
        }
    }

    // MARK: - Registration Failure After Payment

    @Test("registration failure after payment shows specific error")
    func registrationFailedAfterPayment() async {
        var state = makeState()
        state.paymentIntentId = "pi_test"

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        } withDependencies: {
            $0.ckrClient.registerForGame = { _, _, _, _, _, _ in
                throw CKRError.firebaseError("Server error")
            }
        }

        await store.send(.paymentCompleted(.completed)) {
            $0.isRegistering = true
        }

        await store.receive(\._registrationFailed) {
            $0.isRegistering = false
            $0.errorMessage = "Payment succeeded but registration failed: \(CKRError.firebaseError("Server error").localizedDescription). Please try again."
        }
    }

    // MARK: - Retry Registration

    @Test("retryRegistrationTapped retries registration")
    func retryRegistration() async {
        var state = makeState()
        state.paymentIntentId = "pi_test"
        state.errorMessage = "Previous error"

        var registerCalled = false

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        } withDependencies: {
            $0.ckrClient.registerForGame = { _, _, _, _, _, _ in
                registerCalled = true
            }
        }

        await store.send(.retryRegistrationTapped) {
            $0.isRegistering = true
            $0.errorMessage = nil
        }

        await store.receive(\._registrationSucceeded) {
            $0.isRegistering = false
        }

        await store.receive(\.delegate.registrationSucceeded)

        #expect(registerCalled)
    }

    @Test("retryRegistrationTapped does nothing without paymentIntentId")
    func retryWithoutPaymentIntent() async {
        var state = makeState()
        state.errorMessage = "Some error"

        let store = TestStore(initialState: state) {
            PaymentSummaryFeature()
        }

        await store.send(.retryRegistrationTapped)
    }
}
