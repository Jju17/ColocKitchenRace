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
        let mockUser = User.mockUser
        $userInfo.withLock { $0 = mockUser }

        let cohouseUUID = UUID(0)
        let ownerUUID = UUID(1)

        let store = TestStore(initialState: NoCohouseFeature.State()) {
            NoCohouseFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        let expectedCode = cohouseUUID.uuidString.components(separatedBy: "-").first!
        let owner = mockUser.toCohouseUser(cohouseUserId: ownerUUID, isAdmin: true)

        await store.send(.createCohouseButtonTapped) {
            $0.destination = .create(
                CohouseFormFeature.State(
                    wipCohouse: Cohouse(id: cohouseUUID, code: expectedCode, users: [owner]),
                    isNewCohouse: true
                )
            )
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

        await store.send(.confirmCreateCohouseButtonTapped)
    }

    // MARK: - Join Cohouse Flow

    @Test("findExistingCohouseButtonTapped with invalid code shows error to user")
    func findExistingCohouse_notFound_showsError() async {
        let store = TestStore(initialState: NoCohouseFeature.State(cohouseCode: "INVALID")) {
            NoCohouseFeature()
        } withDependencies: {
            $0.cohouseClient.getByCode = { _ in
                throw CohouseClientError.cohouseNotFound
            }
        }

        await store.send(.findExistingCohouseButtonTapped)

        await store.receive(\.cohouseLookupFailed) {
            $0.errorMessage = "No cohouse found with code \"INVALID\"."
        }
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

    // MARK: - Code trimming

    @Test("Cohouse code is trimmed before lookup")
    func cohouseCodeIsTrimmed() async {
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

        await store.receive(\.cohouseLookupFailed) {
            $0.errorMessage = "No cohouse found with code \"1234\"."
        }

        // Code should be trimmed before being sent to the client
        #expect(receivedCode == "1234")
    }
}
