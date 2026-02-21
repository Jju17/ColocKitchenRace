//
//  ProfileCompletionFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 21/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct ProfileCompletionFeatureTests {

    // MARK: - Validation: empty fields

    @Test("Save with all fields empty shows error")
    func saveWithAllFieldsEmpty_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "", lastName: "", phoneNumber: "")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }

        #expect(updateCalled == false)
    }

    @Test("Save with empty first name shows error")
    func saveWithEmptyFirstName_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "", lastName: "Dupont", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }

        #expect(updateCalled == false)
    }

    @Test("Save with empty last name shows error")
    func saveWithEmptyLastName_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }

        #expect(updateCalled == false)
    }

    @Test("Save with empty phone shows error")
    func saveWithEmptyPhone_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please fill in all required fields."
        }

        #expect(updateCalled == false)
    }

    // MARK: - Validation: phone format

    @Test("Save with phone too short shows error")
    func saveWithPhoneTooShort_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "123")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please enter a valid phone number."
        }

        #expect(updateCalled == false)
    }

    @Test("Save with phone containing letters shows error")
    func saveWithPhoneLetters_showsError() async {
        var updateCalled = false

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "abcdefgh")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in updateCalled = true }
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "Please enter a valid phone number."
        }

        #expect(updateCalled == false)
    }

    // MARK: - Validation: valid phone formats

    @Test("Belgian phone format is accepted")
    func belgianPhoneFormat_isValid() {
        #expect(UserValidation.isValidPhone("+32 470 12 34 56") == true)
    }

    @Test("International phone format is accepted")
    func internationalPhoneFormat_isValid() {
        #expect(UserValidation.isValidPhone("+33612345678") == true)
    }

    @Test("Phone with parentheses is accepted")
    func phoneWithParentheses_isValid() {
        #expect(UserValidation.isValidPhone("(02) 123-4567") == true)
    }

    @Test("Phone too short is rejected")
    func phoneTooShort_isInvalid() {
        #expect(UserValidation.isValidPhone("123") == false)
    }

    @Test("Phone with letters is rejected")
    func phoneWithLetters_isInvalid() {
        #expect(UserValidation.isValidPhone("abcdefgh") == false)
    }

    // MARK: - Save: success

    @Test("Successful save sends delegate profileCompleted")
    func successfulSave_sendsDelegate() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in }
        }

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(\._saveSucceeded) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.profileCompleted)

        $userInfo.withLock { $0 = nil }
    }

    @Test("Save updates user with correct values")
    func saveUpdatesUser_withCorrectValues() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        var savedUser: User?

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { user in savedUser = user }
        }

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(\._saveSucceeded) {
            $0.isSaving = false
        }

        await store.receive(\.delegate.profileCompleted)

        #expect(savedUser?.firstName == "Julie")
        #expect(savedUser?.lastName == "Dupont")
        #expect(savedUser?.phoneNumber == "+32 470 12 34 56")

        $userInfo.withLock { $0 = nil }
    }

    // MARK: - Save: failure

    @Test("Failed save shows error message")
    func failedSave_showsError() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = .mockUser }

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        } withDependencies: {
            $0.authenticationClient.updateUser = { _ in
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
            }
        }

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(\._saveFailed) {
            $0.isSaving = false
            $0.errorMessage = "Network error"
        }

        $userInfo.withLock { $0 = nil }
    }

    // MARK: - Initial state

    @Test("Init pre-fills firstName and lastName from userInfo")
    func initPreFillsFromUserInfo() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock {
            $0 = User(id: UUID(), authProvider: .google, firstName: "Julie", lastName: "Dupont", email: "julie@test.com")
        }

        let state = ProfileCompletionFeature.State()

        #expect(state.firstName == "Julie")
        #expect(state.lastName == "Dupont")
        #expect(state.phoneNumber == "")

        $userInfo.withLock { $0 = nil }
    }

    @Test("Init with nil userInfo gives empty fields")
    func initWithNilUserInfo_givesEmptyFields() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }

        let state = ProfileCompletionFeature.State()

        #expect(state.firstName == "")
        #expect(state.lastName == "")
        #expect(state.phoneNumber == "")
    }

    // MARK: - Bindings

    @Test("Fields bind correctly")
    func fieldsBinding() async {
        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "", lastName: "", phoneNumber: "")
        ) {
            ProfileCompletionFeature()
        }

        await store.send(\.binding.firstName, "Julie") {
            $0.firstName = "Julie"
        }

        await store.send(\.binding.lastName, "Dupont") {
            $0.lastName = "Dupont"
        }

        await store.send(\.binding.phoneNumber, "+32 470 12 34 56") {
            $0.phoneNumber = "+32 470 12 34 56"
        }
    }

    // MARK: - Save with no user session

    @Test("Save with no user session shows error")
    func saveWithNoUserSession_showsError() async {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }

        let store = TestStore(
            initialState: ProfileCompletionFeature.State(firstName: "Julie", lastName: "Dupont", phoneNumber: "+32 470 12 34 56")
        ) {
            ProfileCompletionFeature()
        }

        await store.send(.saveButtonTapped) {
            $0.errorMessage = "No user session found."
        }
    }
}
