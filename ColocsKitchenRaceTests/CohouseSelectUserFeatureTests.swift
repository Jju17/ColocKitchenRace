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
        }

        await store.send(.addUserButtonTapped) {
            #expect($0.cohouse.users.count == 2)
            let addedUser = $0.cohouse.users.last!
            #expect(addedUser.surname == "Julien")
            #expect(addedUser.isAdmin == false)
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

    // MARK: - BUG: No duplicate name check

    @Test("BUG: Can add user with same name as existing user (duplicates)")
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

        await store.send(.addUserButtonTapped) {
            // BUG: Duplicate name is allowed
            #expect($0.cohouse.users.count == 2)
            #expect($0.cohouse.users.filter({ $0.surname == "Julien" }).count == 2)
            $0.selectedUser = $0.cohouse.users.last!
            $0.newUserName = ""
        }
    }
}
