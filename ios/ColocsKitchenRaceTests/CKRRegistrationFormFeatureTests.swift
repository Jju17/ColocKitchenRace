//
//  CKRRegistrationFormFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 11/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct CKRRegistrationFormFeatureTests {

    private static let testUser = CohouseUser(id: UUID(), surname: "Julien")

    private func makeState() -> CKRRegistrationFormFeature.State {
        var cohouse = Cohouse.mock
        cohouse.users = [Self.testUser]
        return CKRRegistrationFormFeature.State(
            cohouse: cohouse,
            gameId: "test-game-id",
            pricePerPersonCents: 500
        )
    }

    // MARK: - Toggle User

    @Test("toggleUser adds user to attendingUserIds")
    func toggleUserOn() async {
        let state = makeState()
        let userId = state.cohouse.users.first!.id

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        }

        await store.send(.toggleUser(userId)) {
            $0.attendingUserIds.insert(userId.uuidString)
        }
    }

    @Test("toggleUser removes user from attendingUserIds")
    func toggleUserOff() async {
        var state = makeState()
        let userId = state.cohouse.users.first!.id
        state.attendingUserIds.insert(userId.uuidString)

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        }

        await store.send(.toggleUser(userId)) {
            $0.attendingUserIds.remove(userId.uuidString)
        }
    }

    // MARK: - Continue to Payment

    @Test("continueToPaymentTapped does nothing when no users selected")
    func continueEmpty() async {
        let store = TestStore(initialState: makeState()) {
            CKRRegistrationFormFeature()
        }

        await store.send(.continueToPaymentTapped)
    }

    @Test("continueToPaymentTapped pushes payment summary onto path")
    func continueToPayment() async {
        var state = makeState()
        let userId = state.cohouse.users.first!.id
        state.attendingUserIds.insert(userId.uuidString)

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        }

        await store.send(.continueToPaymentTapped) {
            $0.path.append(.paymentSummary(PaymentSummaryFeature.State(
                gameId: "test-game-id",
                cohouse: $0.cohouse,
                attendingUserIds: $0.attendingUserIds,
                averageAge: 25,
                cohouseType: .mixed,
                pricePerPersonCents: 500,
                participantCount: 1,
                totalCents: 500
            )))
        }
    }

    // MARK: - Multiple Users

    @Test("toggleUser selects multiple users")
    func toggleTwoUsers() async {
        let user2 = CohouseUser(id: UUID(), surname: "Alice")
        var cohouse = Cohouse.mock
        cohouse.users = [Self.testUser, user2]

        let state = CKRRegistrationFormFeature.State(
            cohouse: cohouse,
            gameId: "test-game-id",
            pricePerPersonCents: 500
        )

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        }

        await store.send(.toggleUser(Self.testUser.id)) {
            $0.attendingUserIds.insert(Self.testUser.id.uuidString)
        }

        await store.send(.toggleUser(user2.id)) {
            $0.attendingUserIds.insert(user2.id.uuidString)
        }
    }

    // MARK: - Bindings

    @Test("binding cohouseType updates state")
    func bindingCohouseType() async {
        let store = TestStore(initialState: makeState()) {
            CKRRegistrationFormFeature()
        }

        await store.send(\.binding.cohouseType, CohouseType.girls) {
            $0.cohouseType = .girls
        }

        await store.send(\.binding.cohouseType, CohouseType.boys) {
            $0.cohouseType = .boys
        }
    }

    // MARK: - Computed Properties

    @Test("participantCount and totalCents compute correctly")
    func computedProperties() {
        var state = makeState()
        #expect(state.participantCount == 0)
        #expect(state.totalCents == 0)

        state.attendingUserIds.insert("user-1")
        #expect(state.participantCount == 1)
        #expect(state.totalCents == 500)

        state.attendingUserIds.insert("user-2")
        #expect(state.participantCount == 2)
        #expect(state.totalCents == 1000)
    }
}
