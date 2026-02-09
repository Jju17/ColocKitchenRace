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

    @Test("Edit button opens edit sheet with current cohouse data and original address")
    func editButtonTapped() async {
        let cohouse = Cohouse.mock

        let store = TestStore(
            initialState: CohouseDetailFeature.State(cohouse: Shared(value: cohouse))
        ) {
            CohouseDetailFeature()
        }

        await store.send(.editButtonTapped) {
            $0.destination = .edit(
                CohouseFormFeature.State(
                    wipCohouse: cohouse,
                    originalAddress: cohouse.address
                )
            )
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
                destination: .edit(
                    CohouseFormFeature.State(
                        wipCohouse: wipCohouse,
                        originalAddress: Cohouse.mock.address
                    )
                )
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
                destination: .edit(
                    CohouseFormFeature.State(
                        wipCohouse: cohouse,
                        originalAddress: Cohouse.mock.address
                    )
                )
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

    // MARK: - Address validation on edit

    @Test("Edit with changed address but no validation shows error")
    func confirmEdit_changedAddress_noValidation() async {
        let originalAddress = PostalAddress.mock
        var wipCohouse = Cohouse.mock
        wipCohouse.address = PostalAddress(street: "99 Rue de la Loi", city: "Brussels", postalCode: "1000", country: "Belgique")

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .edit(
                    CohouseFormFeature.State(
                        wipCohouse: wipCohouse,
                        originalAddress: originalAddress
                    )
                )
            )
        ) {
            CohouseDetailFeature()
        }

        await store.send(.confirmEditCohouseButtonTapped) {
            // Address changed but no validation result → error, destination stays open
            guard case var .edit(formState) = $0.destination else { return }
            formState.creationError = "Please wait for address validation before saving."
            $0.destination = .edit(formState)
        }
    }

    @Test("Edit with changed address and valid validation saves successfully")
    func confirmEdit_changedAddress_validated() async {
        var savedCohouse: Cohouse?
        let originalAddress = PostalAddress.mock
        let newAddress = PostalAddress(street: "99 Rue de la Loi", city: "Brussels", postalCode: "1000", country: "Belgique")

        var wipCohouse = Cohouse.mock
        wipCohouse.address = newAddress

        let validatedAddress = ValidatedAddress(
            input: newAddress,
            normalizedStreet: "99 Rue de la Loi",
            normalizedCity: "Brussels",
            normalizedPostalCode: "1000",
            normalizedCountry: "Belgique",
            latitude: 50.85,
            longitude: 4.36,
            confidence: 0.95
        )

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: Cohouse.mock),
                destination: .edit(
                    CohouseFormFeature.State(
                        wipCohouse: wipCohouse,
                        originalAddress: originalAddress,
                        addressValidationResult: .valid(validatedAddress)
                    )
                )
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

        #expect(savedCohouse?.address == newAddress)
    }

    @Test("Edit with unchanged address saves without validation")
    func confirmEdit_unchangedAddress_noValidationNeeded() async {
        var savedCohouse: Cohouse?
        let cohouse = Cohouse.mock

        let store = TestStore(
            initialState: CohouseDetailFeature.State(
                cohouse: Shared(value: cohouse),
                destination: .edit(
                    CohouseFormFeature.State(
                        wipCohouse: cohouse,
                        originalAddress: cohouse.address
                    )
                )
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

        #expect(savedCohouse != nil)
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
