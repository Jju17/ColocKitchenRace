//
//  NoCohouseFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct NoCohouseFeatureTests {

    // MARK: - Create Cohouse Flow

    @Test("createCohouseButtonTapped opens create sheet with correct initial state")
    func createCohouseButtonTapped() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        let store = TestStore(initialState: NoCohouseFeature.State()) {
            NoCohouseFeature()
        }

        await store.send(.createCohouseButtonTapped) {
            // Should present the create destination
            // The UUID is random so we just verify destination is set
            guard case .create(let formState) = $0.destination else {
                Issue.record("Expected destination to be .create")
                return
            }
            #expect(formState.isNewCohouse == true)
            #expect(formState.wipCohouse.users.count == 1)
            #expect(formState.wipCohouse.users.first?.isAdmin == true)
        }
    }

    @Test("createCohouseButtonTapped does nothing when userInfo is nil")
    func createWithoutUserInfo() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }

        let store = TestStore(initialState: NoCohouseFeature.State()) {
            NoCohouseFeature()
        }

        await store.send(.createCohouseButtonTapped)
        // No destination should be set
    }

    @Test("confirmCreateCohouseButtonTapped creates cohouse when valid")
    func confirmCreateCohouse_valid() async {
        var addedCohouse: Cohouse?

        let owner = User.mockUser.toCohouseUser(isAdmin: true)
        let wipCohouse = Cohouse(
            id: UUID(),
            name: "Test Coloc",
            address: .mock,
            code: "ABC123",
            users: [owner]
        )

        let store = TestStore(
            initialState: NoCohouseFeature.State(
                destination: .create(CohouseFormFeature.State(wipCohouse: wipCohouse, isNewCohouse: true))
            )
        ) {
            NoCohouseFeature()
        } withDependencies: {
            $0.cohouseClient.add = { cohouse in
                addedCohouse = cohouse
            }
        }

        await store.send(.confirmCreateCohouseButtonTapped) {
            $0.destination = nil
        }

        #expect(addedCohouse != nil)
        #expect(addedCohouse?.name == "Test Coloc")
    }

    @Test("confirmCreateCohouseButtonTapped does nothing with empty users")
    func confirmCreateCohouse_emptyUsers() async {
        let wipCohouse = Cohouse(id: UUID(), name: "Empty", code: "123456", users: [])

        let store = TestStore(
            initialState: NoCohouseFeature.State(
                destination: .create(CohouseFormFeature.State(wipCohouse: wipCohouse, isNewCohouse: true))
            )
        ) {
            NoCohouseFeature()
        }

        // Should be guarded: totalUsers == 0
        await store.send(.confirmCreateCohouseButtonTapped)
    }

    @Test("confirmCreateCohouseButtonTapped does nothing with empty surname user")
    func confirmCreateCohouse_emptySurname() async {
        let emptyNameUser = CohouseUser(id: UUID(), isAdmin: true, surname: "")
        let wipCohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [emptyNameUser])

        let store = TestStore(
            initialState: NoCohouseFeature.State(
                destination: .create(CohouseFormFeature.State(wipCohouse: wipCohouse, isNewCohouse: true))
            )
        ) {
            NoCohouseFeature()
        }

        // Guard: all surnames must be non-empty
        await store.send(.confirmCreateCohouseButtonTapped)
    }

    @Test("confirmCreateCohouseButtonTapped does nothing without admin")
    func confirmCreateCohouse_noAdmin() async {
        let nonAdminUser = CohouseUser(id: UUID(), isAdmin: false, surname: "Julien")
        let wipCohouse = Cohouse(id: UUID(), name: "Test", code: "123456", users: [nonAdminUser])

        let store = TestStore(
            initialState: NoCohouseFeature.State(
                destination: .create(CohouseFormFeature.State(wipCohouse: wipCohouse, isNewCohouse: true))
            )
        ) {
            NoCohouseFeature()
        }

        // Guard: must have admin
        await store.send(.confirmCreateCohouseButtonTapped)
    }

    // MARK: - Join Cohouse Flow

//    @Test("findExistingCohouseButtonTapped with valid code fetches cohouse")
//    func findExistingCohouse_found() async {
//        let mockCohouse = Cohouse.mock
//
//        let store = TestStore(initialState: NoCohouseFeature.State(cohouseCode: "1234")) {
//            NoCohouseFeature()
//        } withDependencies: {
//            $0.cohouseClient.getByCode = { _ in mockCohouse }
//        }
//
//        await store.send(.findExistingCohouseButtonTapped)
//        await store.receive(\.setUserToCohouseFound) {
//            // First user should be pre-selected
//            $0.destination = .setCohouseUser(
//                CohouseSelectUserFeature.State(
//                    cohouse: mockCohouse,
//                    selectedUser: mockCohouse.users.first!
//                )
//            )
//        }
//    }

    @Test("BUG: findExistingCohouseButtonTapped with invalid code silently prints error")
    func findExistingCohouse_notFound_silentError() async {
        // BUG: When cohouse not found, the error is only printed to console
        // The user sees no feedback (no error message, no alert)
        let store = TestStore(initialState: NoCohouseFeature.State(cohouseCode: "INVALID")) {
            NoCohouseFeature()
        } withDependencies: {
            $0.cohouseClient.getByCode = { _ in
                throw CohouseClientError.cohouseNotFound
            }
        }

        await store.send(.findExistingCohouseButtonTapped)
        // No action received = user sees nothing
    }

    // MARK: - Set User

    @Test("setUserToCohouseFound when user already in cohouse sets cohouse directly")
    func setUserAlreadyInCohouse() async {
        @Shared(.userInfo) var userInfo
        let user = User.mockUser
        $userInfo.withLock { $0 = user }

        var cohouse = Cohouse.mock
        let cohouseUser = CohouseUser(id: UUID(), isAdmin: false, surname: "Test", userId: user.id.uuidString)
        cohouse.users = [cohouseUser]

        let store = TestStore(initialState: NoCohouseFeature.State()) {
            NoCohouseFeature()
        }

        await store.send(.setUserToCohouseFound(cohouse))
        // Should set shared cohouse directly, no destination sheet
    }

    // MARK: - Dismiss

    @Test("Dismiss clears destination")
    func dismissDestination() async {
        let store = TestStore(
            initialState: NoCohouseFeature.State(
                destination: .create(CohouseFormFeature.State(wipCohouse: .mock, isNewCohouse: true))
            )
        ) {
            NoCohouseFeature()
        }

        await store.send(.dismissDestinationButtonTapped) {
            $0.destination = nil
        }
    }

    // MARK: - BUG: Code with trailing spaces

    @Test("BUG: Cohouse code is not trimmed before lookup")
    func cohouseCodeNotTrimmed() async {
        var receivedCode: String?

        let store = TestStore(initialState: NoCohouseFeature.State(cohouseCode: "  1234  ")) {
            NoCohouseFeature()
        } withDependencies: {
            $0.cohouseClient.getByCode = { code in
                receivedCode = code
                throw CohouseClientError.cohouseNotFound
            }
        }

        await store.send(.findExistingCohouseButtonTapped)

        // BUG: The code is passed with spaces, which will likely fail the Firestore lookup
        #expect(receivedCode == "  1234  ")
    }
}
