//
//  UserValidation.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 12/02/2026.
//

import Foundation

/// Single source of truth for profile field validation.
/// Used by both SignupFeature and UserProfileDetailFeature.
enum UserValidation {

    /// Validates the common required profile fields.
    /// - Returns: An error message if validation fails, or `nil` if all fields are valid.
    static func validateProfileFields(
        firstName: String,
        lastName: String,
        email: String?
    ) -> String? {
        let trimmedEmail = (email ?? "").trimmingCharacters(in: .whitespaces)

        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
              !trimmedEmail.isEmpty
        else {
            return "Please fill in all required fields."
        }

        if !isValidEmail(trimmedEmail) {
            return "Please enter a valid email address."
        }

        return nil
    }

    /// Checks whether the given string looks like a valid email address.
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    /// Checks whether the given string looks like a valid phone number.
    /// Accepts optional leading `+`, digits, spaces, hyphens and parentheses, minimum 7 characters.
    static func isValidPhone(_ phone: String) -> Bool {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let pattern = #"^\+?[0-9\s\-()]{7,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
