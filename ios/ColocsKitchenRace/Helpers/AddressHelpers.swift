//
//  AddressHelpers.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import Foundation

// MARK: - Helpers

/**
 Purely offline validation:
 - non-empty fields / minimal length
 - regex for postal codes depending on country
 */
struct AddressSyntaxValidator {
    func isValid(_ address: PostalAddress) -> Bool {
        guard address.street.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 else { return false }
        guard address.city.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return false }
        guard address.country.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return false }

        guard isValidPostalCode(address.postalCode, country: address.country) else {
            return false
        }

        return true
    }

    private func isValidPostalCode(_ code: String, country: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern: String

        let countryLower = country.lowercased()

        switch countryLower {
        case "france", "fr", "français", "french":
            pattern = #"^\d{5}$"#
        case "belgium", "belgië", "belgie", "belgique", "be":
            pattern = #"^\d{4}$"#
        default:
            // minimal fallback (e.g., for other countries)
            pattern = #"^[0-9A-Za-z\- ]{3,10}$"#
        }

        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}


