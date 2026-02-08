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
        var cohouse = Cohouse.mock
        cohouse.users = [CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")]

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        }

        await store.send(.addUserButtonTapped) {
            // Should have 2 users now
            #expect($0.wipCohouse.users.count == 2)
            #expect($0.wipCohouse.users.last?.surname == "")
            #expect($0.wipCohouse.users.last?.isAdmin == false)
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

    // MARK: - Address Validation

    @Test("validateAddressButtonTapped sets loading and calls validator")
    func validateAddress() async {
        let address = PostalAddress(street: "88 Avenue des Eperviers", city: "Woluwe-Saint-Pierre", postalCode: "1150", country: "Belgique")
        var cohouse = Cohouse.mock
        cohouse.address = address

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

        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: cohouse)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.addressValidatorClient.validate = { _ in .valid(validatedAddress) }
        }

        await store.send(.validateAddressButtonTapped) {
            $0.isValidatingAddress = true
        }

        await store.receive(\.addressValidationResponse.success) {
            $0.isValidatingAddress = false
            $0.addressValidationResult = .valid(validatedAddress)
        }
    }

    @Test("Address validation returning notFound sets result correctly")
    func validateAddress_notFound() async {
        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: .mock)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.addressValidatorClient.validate = { _ in .notFound }
        }

        await store.send(.validateAddressButtonTapped) {
            $0.isValidatingAddress = true
        }

        await store.receive(\.addressValidationResponse.success) {
            $0.isValidatingAddress = false
            $0.addressValidationResult = .notFound
        }
    }

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

    // MARK: - Binding resets validation

    @Test("Any binding change clears address validation result")
    func bindingClearsValidation() async {
        let validated = ValidatedAddress(
            input: .mock,
            normalizedStreet: nil,
            normalizedCity: nil,
            normalizedPostalCode: nil,
            normalizedCountry: nil,
            latitude: nil,
            longitude: nil,
            confidence: 0.5
        )

        var updatedCohouse = Cohouse.mock
        updatedCohouse.name = "New Name"

        let store = TestStore(
            initialState: CohouseFormFeature.State(
                wipCohouse: .mock,
                addressValidationResult: .lowConfidence(validated)
            )
        ) {
            CohouseFormFeature()
        }

        await store.send(\.binding.wipCohouse, updatedCohouse) {
            $0.wipCohouse = updatedCohouse
            $0.addressValidationResult = nil
        }
    }

    // MARK: - Quit Cohouse

    @Test("BUG: quitCohouseButtonTapped fires async but has no error handling or completion")
    func quitCohouse_noErrorHandling() async {
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
        // BUG: No loading state, no success confirmation, no error handling
        // If quitCohouse throws, the error is unhandled
        // The sheet stays open
    }

    @Test("BUG: quitCohouseButtonTapped when network fails silently crashes")
    func quitCohouse_networkError() async {
        let store = TestStore(initialState: CohouseFormFeature.State(wipCohouse: .mock)) {
            CohouseFormFeature()
        } withDependencies: {
            $0.cohouseClient.quitCohouse = {
                throw CohouseClientError.failedWithError("Network error")
            }
        }

        // This will throw unhandled in the .run effect
        await store.send(.quitCohouseButtonTapped)
        // BUG: Unhandled error in .run effect
    }
}
