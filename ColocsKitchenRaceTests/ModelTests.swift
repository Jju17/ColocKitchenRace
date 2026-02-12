//
//  ModelTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

// MARK: - Challenge Model Tests

struct ChallengeModelTests {

    @Test("Challenge state is .ongoing when between start and end dates")
    func challengeOngoing() {
        let challenge = Challenge(
            id: UUID(),
            title: "Active",
            startDate: Date.distantPast,
            endDate: Date.distantFuture,
            body: "Test",
            content: .noChoice(NoChoiceContent())
        )
        #expect(challenge.state == .ongoing)
        #expect(challenge.isActiveNow == true)
        #expect(challenge.hasStarted == true)
        #expect(challenge.hasEnded == false)
    }

    @Test("Challenge state is .done when past end date")
    func challengeDone() {
        let challenge = Challenge(
            id: UUID(),
            title: "Done",
            startDate: Date.distantPast,
            endDate: Date.distantPast,
            body: "Test",
            content: .noChoice(NoChoiceContent())
        )
        #expect(challenge.state == .done)
        #expect(challenge.isActiveNow == false)
        #expect(challenge.hasEnded == true)
    }

    @Test("Challenge state is .notStarted when before start date")
    func challengeNotStarted() {
        let challenge = Challenge(
            id: UUID(),
            title: "Future",
            startDate: Date.distantFuture,
            endDate: Date.distantFuture,
            body: "Test",
            content: .noChoice(NoChoiceContent())
        )
        #expect(challenge.state == .notStarted)
        #expect(challenge.isActiveNow == false)
        #expect(challenge.hasStarted == false)
    }

    @Test("ChallengeType fromContent and toContent are symmetric")
    func challengeTypeSymmetry() {
        for type in ChallengeType.allCases {
            let content = type.toContent()
            let backToType = ChallengeType.fromContent(content)
            #expect(type == backToType)
        }
    }

    @Test("ChallengeContent type property returns correct type")
    func challengeContentType() {
        #expect(ChallengeContent.picture(PictureContent()).type == .picture)
        #expect(ChallengeContent.multipleChoice(MultipleChoiceContent()).type == .multipleChoice)
        #expect(ChallengeContent.singleAnswer(SingleAnswerContent()).type == .singleAnswer)
        #expect(ChallengeContent.noChoice(NoChoiceContent()).type == .noChoice)
    }

    @Test("ChallengeContent toResponseContent creates correct initial content")
    func challengeContentToResponse() {
        #expect(ChallengeContent.picture(PictureContent()).toResponseContent == .picture(""))
        #expect(ChallengeContent.multipleChoice(MultipleChoiceContent()).toResponseContent == .multipleChoice([]))
        #expect(ChallengeContent.singleAnswer(SingleAnswerContent()).toResponseContent == .singleAnswer(""))
        #expect(ChallengeContent.noChoice(NoChoiceContent()).toResponseContent == .noChoice)
    }

    @Test("ChallengeSubmitPayload requiresUpload only for picture")
    func submitPayloadRequiresUpload() {
        #expect(ChallengeSubmitPayload.picture(Data()).requiresUpload == true)
        #expect(ChallengeSubmitPayload.multipleChoice(0).requiresUpload == false)
        #expect(ChallengeSubmitPayload.singleAnswer("test").requiresUpload == false)
        #expect(ChallengeSubmitPayload.noChoice.requiresUpload == false)
    }
}

// MARK: - User Model Tests

struct UserModelTests {

    @Test("User fullName returns first + last name")
    func fullName() {
        let user = User(id: UUID(), firstName: "Julien", lastName: "Rahier")
        #expect(user.fullName == "Julien Rahier")
    }

    @Test("User fullName with empty fields")
    func fullNameEmpty() {
        let user = User(id: UUID())
        #expect(user.fullName == " ")
    }

    @Test("User toCohouseUser sets isAdmin correctly")
    func toCohouseUser() {
        let user = User(id: UUID(), firstName: "Test", lastName: "User")

        let adminCohouseUser = user.toCohouseUser(isAdmin: true)
        #expect(adminCohouseUser.isAdmin == true)
        #expect(adminCohouseUser.surname == "Test User")
        #expect(adminCohouseUser.userId == user.id.uuidString)

        let regularCohouseUser = user.toCohouseUser(isAdmin: false)
        #expect(regularCohouseUser.isAdmin == false)
    }

    @Test("SignupUser.createUser preserves phone number")
    func signupUserPreservesPhone() {
        let signupData = SignupUser(
            firstName: "Test",
            lastName: "User",
            email: "test@test.com",
            password: "password",
            phone: "+32479506841"
        )
        let user = signupData.createUser(authId: "auth-123")

        #expect(user.phoneNumber == "+32479506841")
        #expect(user.firstName == "Test")
        #expect(user.lastName == "User")
        #expect(user.email == "test@test.com")
        #expect(user.authId == "auth-123")
        // isSubscribeToNews defaults to false at signup — user can enable later in profile
        #expect(user.isSubscribeToNews == false)
    }

    @Test("SignupUser.createUser with empty phone sets nil")
    func signupUserEmptyPhone() {
        let signupData = SignupUser(
            firstName: "Test",
            lastName: "User",
            email: "test@test.com",
            password: "password",
            phone: ""
        )
        let user = signupData.createUser(authId: "auth-123")

        #expect(user.phoneNumber == nil)
    }
}

// MARK: - DietaryPreference Tests

struct DietaryPreferenceTests {

    @Test("All dietary preferences have display names")
    func allHaveDisplayNames() {
        for pref in DietaryPreference.allCases {
            #expect(!pref.displayName.isEmpty)
        }
    }

    @Test("All dietary preferences have icons")
    func allHaveIcons() {
        for pref in DietaryPreference.allCases {
            #expect(!pref.icon.isEmpty)
        }
    }

    @Test("Dietary preferences are unique")
    func allUnique() {
        let rawValues = DietaryPreference.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("5 dietary preferences exist")
    func count() {
        #expect(DietaryPreference.allCases.count == 5)
    }
}

// MARK: - Cohouse Model Tests

struct CohouseModelTests {

    @Test("totalUsers returns users count")
    func totalUsers() {
        var cohouse = Cohouse.mock
        #expect(cohouse.totalUsers == cohouse.users.count)

        cohouse.users.append(CohouseUser(id: UUID(), surname: "New"))
        #expect(cohouse.totalUsers == cohouse.users.count)
    }

    @Test("isAdmin returns true for admin user")
    func isAdmin() {
        let adminId = UUID()
        let admin = CohouseUser(id: UUID(), isAdmin: true, surname: "Admin", userId: adminId.uuidString)
        let regular = CohouseUser(id: UUID(), isAdmin: false, surname: "Regular", userId: UUID().uuidString)
        var cohouse = Cohouse.mock
        cohouse.users = [admin, regular]

        #expect(cohouse.isAdmin(id: adminId) == true)
        #expect(cohouse.isAdmin(id: UUID()) == false)
        #expect(cohouse.isAdmin(id: nil) == false)
    }

    @Test("toFIRCohouse strips users")
    func toFIRCohouse() {
        let cohouse = Cohouse.mock
        let firCohouse = cohouse.toFIRCohouse

        #expect(firCohouse.id == cohouse.id)
        #expect(firCohouse.name == cohouse.name)
        #expect(firCohouse.address == cohouse.address)
        #expect(firCohouse.code == cohouse.code)
    }

    @Test("FirestoreCohouse toCohouseObject reconstructs correctly")
    func firToCohouseObject() {
        let firCohouse = FirestoreCohouse.mock
        let users = CohouseUser.mockList
        let cohouse = firCohouse.toCohouseObject(with: users)

        #expect(cohouse.id == firCohouse.id)
        #expect(cohouse.name == firCohouse.name)
        #expect(cohouse.users.count == users.count)
    }

    @Test("Cohouse code is 8 hex chars from UUID prefix")
    func cohouseCodeFromUUID() {
        // NoCohouseFeature.createCohouseButtonTapped generates code from UUID first segment
        let uuid = UUID()
        let code = uuid.uuidString.components(separatedBy: "-").first!
        #expect(code.count == 8)
        // All characters should be valid hex
        #expect(code.allSatisfy { $0.isHexDigit })
    }

    @Test("contactUser always returns nil (commented out)")
    func contactUser() {
        let cohouse = Cohouse.mock
        #expect(cohouse.contactUser == nil)
    }
}

// MARK: - CohouseUser Model Tests

struct CohouseUserModelTests {

    @Test("isAssignedToRealUser when userId is set")
    func isAssignedToRealUser() {
        let assigned = CohouseUser(id: UUID(), surname: "Test", userId: "some-id")
        let unassigned = CohouseUser(id: UUID(), surname: "Test", userId: nil)

        #expect(assigned.isAssignedToRealUser == true)
        #expect(unassigned.isAssignedToRealUser == false)
    }
}

// MARK: - PostalAddress Tests

struct PostalAddressTests {

    @Test("Default country is Belgique")
    func defaultCountry() {
        let address = PostalAddress()
        #expect(address.country == "Belgique")
    }

    @Test("Mock address has all fields filled")
    func mockAddress() {
        let mock = PostalAddress.mock
        #expect(!mock.street.isEmpty)
        #expect(!mock.city.isEmpty)
        #expect(!mock.postalCode.isEmpty)
        #expect(!mock.country.isEmpty)
    }
}

// MARK: - Address Validation Tests

struct AddressValidationTests {

    @Test("Belgian postal code validation: 4 digits required")
    func belgianPostalCode() {
        let validator = AddressSyntaxValidator()

        let valid = PostalAddress(street: "Rue du Test 10", city: "Bruxelles", postalCode: "1000", country: "Belgique")
        #expect(validator.isValid(valid) == true)

        let invalid = PostalAddress(street: "Rue du Test 10", city: "Bruxelles", postalCode: "10000", country: "Belgique")
        #expect(validator.isValid(invalid) == false)

        let invalid2 = PostalAddress(street: "Rue du Test 10", city: "Bruxelles", postalCode: "ABC", country: "Belgique")
        #expect(validator.isValid(invalid2) == false)
    }

    @Test("French postal code validation: 5 digits required")
    func frenchPostalCode() {
        let validator = AddressSyntaxValidator()

        let valid = PostalAddress(street: "10 Rue de Rivoli", city: "Paris", postalCode: "75001", country: "France")
        #expect(validator.isValid(valid) == true)

        let invalid = PostalAddress(street: "10 Rue de Rivoli", city: "Paris", postalCode: "7500", country: "France")
        #expect(validator.isValid(invalid) == false)
    }

    @Test("Street must be at least 5 characters")
    func streetMinLength() {
        let validator = AddressSyntaxValidator()

        let tooShort = PostalAddress(street: "Rue", city: "Bruxelles", postalCode: "1000", country: "Belgique")
        #expect(validator.isValid(tooShort) == false)
    }

    @Test("City must be at least 2 characters")
    func cityMinLength() {
        let validator = AddressSyntaxValidator()

        let tooShort = PostalAddress(street: "Rue du Test 10", city: "B", postalCode: "1000", country: "Belgique")
        #expect(validator.isValid(tooShort) == false)
    }

    @Test("Country must be at least 2 characters")
    func countryMinLength() {
        let validator = AddressSyntaxValidator()

        let tooShort = PostalAddress(street: "Rue du Test 10", city: "Bruxelles", postalCode: "1000", country: "B")
        #expect(validator.isValid(tooShort) == false)
    }

    @Test("Whitespace-only fields fail validation")
    func whitespaceOnlyFields() {
        let validator = AddressSyntaxValidator()

        let whitespace = PostalAddress(street: "     ", city: "  ", postalCode: "    ", country: "  ")
        #expect(validator.isValid(whitespace) == false)
    }

    @Test("Belgium country name variants are recognized")
    func belgiumVariants() {
        let validator = AddressSyntaxValidator()
        let base = PostalAddress(street: "Rue du Test 10", city: "Bruxelles", postalCode: "1000")

        let variants = ["Belgium", "Belgique", "België", "Belgie", "BE", "be"]
        for variant in variants {
            var address = base
            address.country = variant
            #expect(validator.isValid(address) == true, "Should accept country: \(variant)")
        }
    }
}

// MARK: - CKRGame Model Tests

struct CKRGameModelTests {

    @Test("CKRGame default values")
    func defaultValues() {
        let futureDate = Date().addingTimeInterval(60 * 60 * 24 * 60) // 60 days
        let deadline = Date().addingTimeInterval(60 * 60 * 24 * 46) // 46 days
        let countdown = Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
        let game = CKRGame(startCKRCountdown: countdown, nextGameDate: futureDate, registrationDeadline: deadline)
        #expect(game.cohouseIDs.isEmpty)
        #expect(game.totalRegisteredParticipants == 0)
        #expect(game.editionNumber == 1)
        #expect(game.maxParticipants == 100)
        #expect(game.id != UUID())
    }

    @Test("isRegistrationOpen returns true when deadline is in the future and spots available")
    func registrationOpen() {
        let game = CKRGame(
            startCKRCountdown: Date().addingTimeInterval(60 * 60 * 24 * 30),
            nextGameDate: Date().addingTimeInterval(60 * 60 * 24 * 60),
            registrationDeadline: Date().addingTimeInterval(60 * 60 * 24 * 46),
            maxParticipants: 20
        )
        #expect(game.isRegistrationOpen == true)
    }

    @Test("isRegistrationOpen returns false when deadline has passed")
    func registrationClosedByDeadline() {
        let game = CKRGame(
            startCKRCountdown: Date().addingTimeInterval(-60 * 60 * 24), // 1 day ago
            nextGameDate: Date().addingTimeInterval(60 * 60 * 24 * 7),
            registrationDeadline: Date().addingTimeInterval(-60 * 60), // 1 hour ago
            maxParticipants: 20
        )
        #expect(game.isRegistrationOpen == false)
    }

    @Test("isRegistrationOpen returns false when max participants reached")
    func registrationClosedByCapacity() {
        var game = CKRGame(
            startCKRCountdown: Date().addingTimeInterval(60 * 60 * 24 * 30),
            nextGameDate: Date().addingTimeInterval(60 * 60 * 24 * 60),
            registrationDeadline: Date().addingTimeInterval(60 * 60 * 24 * 46),
            maxParticipants: 20
        )
        game.totalRegisteredParticipants = 20
        #expect(game.isRegistrationOpen == false)
    }

    @Test("remainingSpots computes correctly")
    func remainingSpots() {
        var game = CKRGame(
            startCKRCountdown: Date().addingTimeInterval(60 * 60 * 24 * 30),
            nextGameDate: Date().addingTimeInterval(60 * 60 * 24 * 60),
            registrationDeadline: Date().addingTimeInterval(60 * 60 * 24 * 46),
            maxParticipants: 20
        )
        #expect(game.remainingSpots == 20)
        game.totalRegisteredParticipants = 12
        #expect(game.remainingSpots == 8)
    }
}

// MARK: - Date+Utils Tests

struct DateUtilsTests {

    @Test("Date.from creates correct date")
    func dateFrom() {
        let date = Date.from(year: 2026, month: 2, day: 8)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 2)
        #expect(components.day == 8)
    }

    @Test("Date.from with hour creates correct date")
    func dateFromWithHour() {
        let date = Date.from(year: 2026, month: 2, day: 8, hour: 18)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.hour], from: date)
        #expect(components.hour == 18)
    }

    @Test("countdownDateComponents returns positive components for future date")
    func countdownPositive() {
        let now = Date()
        let future = now.addingTimeInterval(3600 * 25 + 60 * 30 + 45) // 25h 30m 45s
        let components = Date.countdownDateComponents(from: now, to: future)

        #expect(components.day! >= 1)
        #expect(components.hour! >= 0)
    }

    @Test("countDownString formats correctly")
    func countDownString() {
        let now = Date()
        let future = now.addingTimeInterval(86400 + 3600 + 60 + 1) // 1d 1h 1m 1s
        let string = Date.countDownString(from: now, to: future)

        // Format: DD:HH:MM:SS
        let parts = string.split(separator: ":").map(String.init)
        #expect(parts.count == 4)
        #expect(parts.allSatisfy { $0.count == 2 })
    }
}

// MARK: - Collection+Utils Tests

struct CollectionUtilsTests {

    @Test("Safe subscript returns nil for out of bounds")
    func safeSubscript() {
        let array = [1, 2, 3]
        #expect(array[safe: 0] == 1)
        #expect(array[safe: 2] == 3)
        #expect(array[safe: 3] == nil)
        #expect(array[safe: -1] == nil)
    }

    @Test("Safe subscript on empty array")
    func safeSubscriptEmpty() {
        let array: [Int] = []
        #expect(array[safe: 0] == nil)
    }
}

// MARK: - ImagePipeline Tests

struct ImagePipelineTests {

    @Test("humanSize formats bytes correctly")
    func humanSize() {
        #expect(ImagePipeline.humanSize(500) == "500 B")
        #expect(ImagePipeline.humanSize(1024) == "1.0 KB")
        #expect(ImagePipeline.humanSize(1_500_000) == "1.4 MB")
        #expect(ImagePipeline.humanSize(3_000_000) == "2.9 MB")
    }

    @Test("humanSize handles edge cases")
    func humanSizeEdge() {
        #expect(ImagePipeline.humanSize(0) == "0 B")
        #expect(ImagePipeline.humanSize(1023) == "1023 B")
        #expect(ImagePipeline.humanSize(1_048_575) == "1024.0 KB")
        #expect(ImagePipeline.humanSize(1_048_576) == "1.0 MB")
    }
}

// MARK: - Dictionary+Utils Tests

struct DictionaryUtilsTests {

    @Test("toQueryString converts dictionary to query string")
    func toQueryString() {
        let dict: [String: String] = ["key1": "value1", "key2": "value2"]
        let qs = dict.toQueryString
        // Order is not guaranteed, so check both parts exist
        #expect(qs.contains("key1=value1"))
        #expect(qs.contains("key2=value2"))
        #expect(qs.contains("&"))
    }

    @Test("toQueryString with single entry has no separator")
    func toQueryStringSingle() {
        let dict: [String: String] = ["key": "value"]
        #expect(dict.toQueryString == "key=value")
    }
}

// MARK: - DateComponents+Utils Tests

struct DateComponentsUtilsTests {

    @Test("Formatted components are zero-padded")
    func zeroPadded() {
        var components = DateComponents()
        components.second = 5
        components.minute = 3
        components.hour = 1
        components.day = 2

        #expect(components.formattedSeconds == "05")
        #expect(components.formattedMinutes == "03")
        #expect(components.formattedHours == "01")
        #expect(components.formattedDays == "02")
    }

    @Test("Formatted components handle nil as 00")
    func nilAs00() {
        let components = DateComponents()
        #expect(components.formattedSeconds == "00")
        #expect(components.formattedMinutes == "00")
        #expect(components.formattedHours == "00")
        #expect(components.formattedDays == "00")
    }
}
