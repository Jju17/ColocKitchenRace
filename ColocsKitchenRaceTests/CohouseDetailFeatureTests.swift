//
//  CohouseDetailFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import ColocsKitchenRace

@MainActor
struct CohouseDetailFeatureTests {

    // MARK: - Edit Flow

    @Test("Edit button opens edit sheet with current cohouse data")
    func editButtonTapped() async {
        let cohouse = Cohouse.mock

        let store = TestStore(
            initialState: CohouseDetailFeature.State(cohouse: Shared(value: cohouse))
        ) {
            CohouseDetailFeature()
        }

        await store.send(.editButtonTapped) {
            $0.destination = .edit(CohouseFormFeature.State(wipCohouse: cohouse))
        }
    }

    @Test("confirmEditCohouseButtonTapped removes empty non-admin users and saves")
    func confirmEdit_removesEmptyUsers() async {
        var savedCohouse: Cohouse?
        let admin = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")
        let validUser = CohouseUser(id: UUID(), isAdmin: false, surname: "Valid")
        let emptyUser = CohouseUser(id: UUID(), isAdmin: false, surname: "")

        var wipCohouse = Cohouse.mock
        wipCohouse.users = [admin, validUser, emptyUser]

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .edit(CohouseFormFeature.State(wipCohouse: wipCohouse))
            )
        ) {
            CohouseDetailFeature()
        } withDependencies: {
            $0.cohouseClient.set = { _, cohouse in
                savedCohouse = cohouse
            }
        }

        await store.send(.confirmEditCohouseButtonTapped) {
            $0.destination = nil
        }

        // Empty non-admin user should be removed
        #expect(savedCohouse?.users.count == 2)
        #expect(savedCohouse?.users.contains(where: { $0.surname.isEmpty }) == false)
    }

    @Test("confirmEditCohouseButtonTapped handles network error gracefully")
    func confirmEdit_networkError() async {
        var cohouse = Cohouse.mock
        cohouse.users = [CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")]

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .edit(CohouseFormFeature.State(wipCohouse: cohouse))
            )
        ) {
            CohouseDetailFeature()
        } withDependencies: {
            $0.cohouseClient.set = { _, _ in
                throw CohouseClientError.failedWithError("Network error")
            }
        }

        await store.send(.confirmEditCohouseButtonTapped) {
            $0.destination = nil
        }
        // Error is caught and logged, no crash
    }

    // MARK: - Dismiss

    @Test("Dismiss clears edit destination")
    func dismissEdit() async {
        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .edit(CohouseFormFeature.State(wipCohouse: .mock))
            )
        ) {
            CohouseDetailFeature()
        }

        await store.send(.dismissEditCohouseButtonTapped) {
            $0.destination = nil
        }
    }

    // MARK: - Refresh

    @Test("Refresh loads current cohouse data")
    func refresh_success() async {
        let cohouse = Cohouse.mock

        let store = TestStore(
            initialState: CohouseDetailFeature.State(cohouse: Shared(value: cohouse))
        ) {
            CohouseDetailFeature()
        } withDependencies: {
            $0.cohouseClient.get = { _ in cohouse }
        }

        await store.send(.refresh)
    }

    @Test("Refresh when user removed from cohouse shows alert")
    func refresh_userRemoved() async {
        let cohouse = Cohouse.mock

        let store = TestStore(
            initialState: CohouseDetailFeature.State(cohouse: Shared(value: cohouse))
        ) {
            CohouseDetailFeature()
        } withDependencies: {
            $0.cohouseClient.get = { _ in
                throw CohouseClientError.userNotInCohouse
            }
        }

        await store.send(.refresh)
        await store.receive(\.userWasRemovedFromCohouse) {
            $0.destination = .alert(
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
        }
    }

    @Test("Alert OK button clears shared cohouse")
    func alertOK_clearsCohouse() async {
        @Shared(.cohouse) var currentCohouse
        $currentCohouse.withLock { $0 = .mock }

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .alert(
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
            )
        ) {
            CohouseDetailFeature()
        }

        await store.send(.destination(.presented(.alert(.okButtonTapped)))) {
            $0.destination = nil
        }
    }
}
