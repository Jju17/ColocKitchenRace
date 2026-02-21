//
//  CohouseSelectUserFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct CohouseSelectUserFeatureTests {

    // MARK: - Add User

    @Test("addUserButtonTapped with non-empty name adds user and selects them")
    func addUser() async {
        let newUserUUID = UUID(0)
        let firstUser = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin")
        let cohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [firstUser])

        let store = TestStore(
            initialState: CohouseSelectUserFeature.State(
                cohouse: cohouse,
                selectedUser: firstUser,
                newUserName: "Julien"
            )
        ) {
            CohouseSelectUserFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addUserButtonTapped) {
            let addedUser = CohouseUser(id: newUserUUID, surname: "Julien")
            $0.cohouse.users.append(addedUser)
            $0.selectedUser = addedUser
            $0.newUserName = ""
        }
    }

    @Test("addUserButtonTapped with empty name does nothing")
    func addUserEmptyName() async {
        let firstUser = CohouseUser.mock
        let cohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [firstUser])

        let store = TestStore(
            initialState: CohouseSelectUserFeature.State(
                cohouse: cohouse,
                selectedUser: firstUser,
                newUserName: ""
            )
        ) {
            CohouseSelectUserFeature()
        }

        await store.send(.addUserButtonTapped)
        // Should do nothing when name is empty
    }

    // MARK: - Binding

    @Test("newUserName binding updates state")
    func newUserNameBinding() async {
        let firstUser = CohouseUser.mock
        let cohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [firstUser])

        let store = TestStore(
            initialState: CohouseSelectUserFeature.State(
                cohouse: cohouse,
                selectedUser: firstUser
            )
        ) {
            CohouseSelectUserFeature()
        }

        await store.send(\.binding.newUserName, "New Name") {
            $0.newUserName = "New Name"
        }
    }

    // MARK: - Duplicate name check

    @Test("addUserButtonTapped with duplicate name does nothing")
    func addDuplicateName() async {
        let firstUser = CohouseUser(id: UUID(), isAdmin: true, surname: "Julien")
        let cohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [firstUser])

        let store = TestStore(
            initialState: CohouseSelectUserFeature.State(
                cohouse: cohouse,
                selectedUser: firstUser,
                newUserName: "Julien" // Same name!
            )
        ) {
            CohouseSelectUserFeature()
        }

        // Duplicate name is rejected — no state change
        await store.send(.addUserButtonTapped)
    }

    @Test("addUserButtonTapped with duplicate name (case insensitive) does nothing")
    func addDuplicateNameCaseInsensitive() async {
        let firstUser = CohouseUser(id: UUID(), isAdmin: true, surname: "Julien")
        let cohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [firstUser])

        let store = TestStore(
            initialState: CohouseSelectUserFeature.State(
                cohouse: cohouse,
                selectedUser: firstUser,
                newUserName: "julien" // Same name, different case
            )
        ) {
            CohouseSelectUserFeature()
        }

        await store.send(.addUserButtonTapped)
    }
}
