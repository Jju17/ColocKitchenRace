//
//  EmailVerificationFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 12/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

@MainActor
struct EmailVerificationFeatureTests {

    // MARK: - Check Verification

    @Test("checkVerificationTapped when email not yet verified shows message")
    func checkVerification_notVerified() async {
        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.reloadCurrentUser = { false }
        }

        await store.send(.checkVerificationTapped) {
            $0.isChecking = true
        }

        await store.receive(\._checkResult) {
            $0.isChecking = false
            $0.message = "Email not yet verified. Check your inbox."
        }
    }

    @Test("checkVerificationTapped when email is verified clears message")
    func checkVerification_verified() async {
        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.reloadCurrentUser = { true }
        }

        await store.send(.checkVerificationTapped) {
            $0.isChecking = true
        }

        await store.receive(\._checkResult) {
            $0.isChecking = false
        }
    }

    @Test("checkVerificationTapped handles reload error gracefully")
    func checkVerification_error() async {
        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.reloadCurrentUser = {
                throw NSError(domain: "test", code: 1)
            }
        }

        await store.send(.checkVerificationTapped) {
            $0.isChecking = true
        }

        await store.receive(\._checkResult) {
            $0.isChecking = false
            $0.message = "Email not yet verified. Check your inbox."
        }
    }

    // MARK: - Resend Email

    @Test("resendEmailTapped success shows confirmation message")
    func resendEmail_success() async {
        var resendCalled = false

        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.resendVerificationEmail = {
                resendCalled = true
            }
        }

        await store.send(.resendEmailTapped) {
            $0.isResending = true
        }

        await store.receive(\._resendSucceeded) {
            $0.isResending = false
            $0.message = "Verification email sent! Check your inbox."
        }

        #expect(resendCalled)
    }

    @Test("resendEmailTapped failure shows error message")
    func resendEmail_failure() async {
        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.resendVerificationEmail = {
                throw NSError(domain: "test", code: 1)
            }
        }

        await store.send(.resendEmailTapped) {
            $0.isResending = true
        }

        await store.receive(\._resendFailed) {
            $0.isResending = false
            $0.message = "Failed to send email. Try again."
        }
    }

    // MARK: - Sign Out

    @Test("signOutTapped calls signOut")
    func signOut() async {
        var signOutCalled = false

        let store = TestStore(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        } withDependencies: {
            $0.authenticationClient.signOut = {
                signOutCalled = true
            }
        }

        await store.send(.signOutTapped)

        #expect(signOutCalled)
    }
}

// MARK: - UserValidation Email Tests

@MainActor
struct UserValidationEmailTests {

    @Test("isValidEmail accepts valid emails")
    func validEmails() {
        #expect(UserValidation.isValidEmail("test@example.com"))
        #expect(UserValidation.isValidEmail("user.name@domain.co"))
        #expect(UserValidation.isValidEmail("user+tag@sub.domain.com"))
        #expect(UserValidation.isValidEmail("a@b.cd"))
    }

    @Test("isValidEmail rejects invalid emails")
    func invalidEmails() {
        #expect(!UserValidation.isValidEmail(""))
        #expect(!UserValidation.isValidEmail("abc"))
        #expect(!UserValidation.isValidEmail("@domain.com"))
        #expect(!UserValidation.isValidEmail("user@"))
        #expect(!UserValidation.isValidEmail("user@.com"))
        #expect(!UserValidation.isValidEmail("user@domain"))
        #expect(!UserValidation.isValidEmail("user @domain.com"))
    }

    @Test("validateProfileFields rejects invalid email format")
    func validateProfileFields_invalidEmail() {
        let result = UserValidation.validateProfileFields(
            firstName: "John",
            lastName: "Doe",
            email: "not-an-email"
        )
        #expect(result == "Please enter a valid email address.")
    }

    @Test("validateProfileFields accepts valid email format")
    func validateProfileFields_validEmail() {
        let result = UserValidation.validateProfileFields(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        #expect(result == nil)
    }
}
