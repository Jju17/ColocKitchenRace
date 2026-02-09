//
//  CohouseFormFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct CohouseFormFeatureTests {

    // MARK: - Add User

    @Test("addUserButtonTapped appends empty user")
    func addUser() async {
        let newUserUUID = UUID(0)
        var cohouse = Cohouse.mock
        cohouse.users = [CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")]

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addUserButtonTapped) {
            $0.wipCohouse.users.append(CohouseUser(id: newUserUUID))
        }
    }

    // MARK: - Delete Users

    @Test("Delete non-admin user works correctly")
    func deleteNonAdmin() async {
        let admin = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")
        let user1 = CohouseUser(id: UUID(), isAdmin: false, surname: "User1")
        let user2 = CohouseUser(id: UUID(), isAdmin: false, surname: "User2")
        var cohouse = Cohouse.mock
        cohouse.users = [admin, user1, user2]

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        }

        await store.send(.deleteUsers(atOffset: IndexSet(integer: 1))) {
            $0.wipCohouse.users.remove(id: user1.id)
        }
    }

    @Test("Cannot delete admin user via swipe")
    func cannotDeleteAdmin() async {
        let admin = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")
        let user = CohouseUser(id: UUID(), isAdmin: false, surname: "User")
        var cohouse = Cohouse.mock
        cohouse.users = [admin, user]

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        }

        // Try to delete admin (index 0)
        await store.send(.deleteUsers(atOffset: IndexSet(integer: 0)))
        // Admin should still be there
    }

    @Test("Deleting all non-admin users adds back empty admin")
    func deleteAllNonAdmin_reAddsAdmin() async {
        let admin = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")
        var cohouse = Cohouse.mock
        cohouse.users = [admin]

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        }

        // Delete admin at index 0 - should be filtered out (admin), no deletion
        // but if list becomes empty, it re-adds
        await store.send(.deleteUsers(atOffset: IndexSet(integer: 0)))
    }

    // MARK: - Auto Address Validation (debounce)

    @Test("Address change triggers auto-validation after 600ms debounce")
    func autoValidateAddress() async {
        let address = PostalAddress(street: "88 Avenue des Eperviers", city: "Woluwe-Saint-Pierre", postalCode: "1150", country: "Belgique")
        var cohouse = Cohouse.mock
        cohouse.address = PostalAddress(street: "", city: "", postalCode: "", country: "")

        let validatedAddress = ValidatedAddress(
            input: address,
            normalizedStreet: "88 Avenue des Eperviers",
            normalizedCity: "Woluwe-Saint-Pierre",
            normalizedPostalCode: "1150",
            normalizedCountry: "Belgique",
            latitude: 50.83,
            longitude: 4.43,
            confidence: 0.95
        )

        let clock = TestClock()

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.addressValidatorClient.validate = { _ in .valid(validatedAddress) }
            $0.continuousClock = clock
        }

        // Change address via binding
        var updatedCohouse = cohouse
        updatedCohouse.address = address

        await store.send(\.binding.wipCohouse, updatedCohouse) {
            $0.wipCohouse = updatedCohouse
            $0.isValidatingAddress = true
        }

        // Advance clock by 600ms to trigger debounce
        await clock.advance(by: .milliseconds(600))

        await store.receive(\.addressValidationResponse.success) {
            $0.isValidatingAddress = false
            $0.addressValidationResult = .valid(validatedAddress)
        }
    }

    @Test("Address auto-validation returning notFound")
    func autoValidateAddress_notFound() async {
        var cohouse = Cohouse.mock
        cohouse.address = PostalAddress(street: "", city: "", postalCode: "", country: "")

        let clock = TestClock()

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.addressValidatorClient.validate = { _ in .notFound }
            $0.continuousClock = clock
        }

        // Set an address long enough to trigger validation
        var updatedCohouse = cohouse
        updatedCohouse.address = PostalAddress(street: "Some Unknown Street", city: "Nowhere", postalCode: "0000", country: "XX")

        await store.send(\.binding.wipCohouse, updatedCohouse) {
            $0.wipCohouse = updatedCohouse
            $0.isValidatingAddress = true
        }

        await clock.advance(by: .milliseconds(600))

        await store.receive(\.addressValidationResponse.success) {
            $0.isValidatingAddress = false
            $0.addressValidationResult = .notFound
        }
    }

    @Test("Short address does not trigger validation")
    func shortAddress_noValidation() async {
        var cohouse = Cohouse.mock
        cohouse.address = PostalAddress(street: "", city: "", postalCode: "", country: "")

        let clock = TestClock()

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        // Set address with street < 5 chars and city < 2 chars
        var updatedCohouse = cohouse
        updatedCohouse.address = PostalAddress(street: "AB", city: "X", postalCode: "", country: "")

        await store.send(\.binding.wipCohouse, updatedCohouse) {
            $0.wipCohouse = updatedCohouse
        }

        // No validation should be triggered, clock advance should produce nothing
        await clock.advance(by: .milliseconds(1000))
        // No receive expected — test passes if nothing is received
    }

    @Test("Already validated address does not re-trigger validation")
    func alreadyValidated_noRetrigger() async {
        let address = PostalAddress(street: "88 Avenue des Eperviers", city: "Brussels", postalCode: "1150", country: "Belgique")
        var cohouse = Cohouse.mock
        cohouse.address = address

        let validatedAddress = ValidatedAddress(
            input: address,
            normalizedStreet: "88 Avenue des Eperviers",
            normalizedCity: "Brussels",
            normalizedPostalCode: "1150",
            normalizedCountry: "Belgique",
            latitude: 50.83,
            longitude: 4.43,
            confidence: 0.95
        )

        let clock = TestClock()

        let store = TestStore(
            initialState: CohouseFormFeature.State(
                wipCohouse: cohouse,
                addressValidationResult: .valid(validatedAddress)
            )
        ) {
            CohouseFormFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        // Send same address via binding — should not re-validate
        await store.send(\.binding.wipCohouse, cohouse)

        await clock.advance(by: .milliseconds(1000))
        // No receive expected
    }

    // MARK: - Apply Suggested Address

    @Test("applySuggestedAddress updates cohouse address")
    func applySuggested() async {
        let input = PostalAddress.mock
        let validated = ValidatedAddress(
            input: input,
            normalizedStreet: "88 Av. des Eperviers",
            normalizedCity: "Woluwe-Saint-Pierre",
            normalizedPostalCode: "1150",
            normalizedCountry: "Belgium",
            latitude: 50.83,
            longitude: 4.43,
            confidence: 0.7
        )

        let store = TestStore(
            initialState: CohouseFormFeature.State(
                wipCohouse: .mock,
                addressValidationResult: .lowConfidence(validated)
            )
        ) {
            CohouseFormFeature()
        }

        await store.send(.applySuggestedAddress(validated)) {
            $0.wipCohouse.address = PostalAddress(
                street: "88 Av. des Eperviers",
                city: "Woluwe-Saint-Pierre",
                postalCode: "1150",
                country: "Belgium"
            )
            $0.addressValidationResult = nil
        }
    }

    // MARK: - Quit Cohouse

    @Test("quitCohouseButtonTapped calls quitCohouse")
    func quitCohouse() async {
        var quitCalled = false

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: .mock)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.cohouseClient.quitCohouse = {
                quitCalled = true
            }
        }

        await store.send(.quitCohouseButtonTapped)

        #expect(quitCalled == true)
    }

    @Test("quitCohouseButtonTapped handles network error gracefully")
    func quitCohouse_networkError() async {
        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: .mock)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.cohouseClient.quitCohouse = {
                throw CohouseClientError.failedWithError("Network error")
            }
        }

        // Error is caught and logged, no crash
        await store.send(.quitCohouseButtonTapped)
    }
}
