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
            gameId: "test-game-id"
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

    // MARK: - Submit

    @Test("submitButtonTapped does nothing when no users selected")
    func submitEmpty() async {
        let store = TestStore(initialState: makeState()) {
            CKRRegistrationFormFeature()
        }

        await store.send(.submitButtonTapped)
    }

    @Test("submitButtonTapped calls registerForGame and delegates on success")
    func submitSuccess() async {
        var state = makeState()
        let userId = state.cohouse.users.first!.id
        state.attendingUserIds.insert(userId.uuidString)

        var registerCalled = false

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        } withDependencies: {
            $0.ckrClient.registerForGame = { _, _, _, _, _ in
                registerCalled = true
            }
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.registrationSucceeded) {
            $0.isSubmitting = false
        }

        await store.receive(\.delegate.registrationSucceeded)

        #expect(registerCalled)
    }

    @Test("toggleUser selects multiple users")
    func toggleTwoUsers() async {
        let user2 = CohouseUser(id: UUID(), surname: "Alice")
        var cohouse = Cohouse.mock
        cohouse.users = [Self.testUser, user2]

        let state = CKRRegistrationFormFeature.State(
            cohouse: cohouse,
            gameId: "test-game-id"
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

    @Test("submitButtonTapped shows error on failure")
    func submitFailure() async {
        var state = makeState()
        let userId = state.cohouse.users.first!.id
        state.attendingUserIds.insert(userId.uuidString)

        let store = TestStore(initialState: state) {
            CKRRegistrationFormFeature()
        } withDependencies: {
            $0.ckrClient.registerForGame = { _, _, _, _, _ in
                throw CKRError.firebaseError("Network error")
            }
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.registrationFailed) {
            $0.isSubmitting = false
            $0.errorMessage = CKRError.firebaseError("Network error").localizedDescription
        }
    }
}
