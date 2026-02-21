//
//  AddressHelpers.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import CoreLocation
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

/**
 Wrapper around CLGeocoder + computes a confidence score.
 */
final class AddressGeocoderValidator {
    private let geocoder = CLGeocoder()

    func validate(address: PostalAddress) async throws -> ValidatedAddress? {
        let addressString = buildAddressString(from: address)
        let placemarks = try await geocode(addressString: addressString)

        guard let placemark = placemarks.first else {
            return nil
        }

        let normalizedStreet = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let normalizedCity = placemark.locality ?? placemark.subAdministrativeArea
        let normalizedPostalCode = placemark.postalCode
        let normalizedCountry = placemark.country

        let confidence = computeConfidence(
            input: address,
            placemarkStreet: normalizedStreet,
            placemarkPostalCode: normalizedPostalCode,
            placemarkCity: normalizedCity,
            placemarkCountry: normalizedCountry
        )

        return ValidatedAddress(
            input: address,
            normalizedStreet: normalizedStreet.isEmpty ? nil : normalizedStreet,
            normalizedCity: normalizedCity,
            normalizedPostalCode: normalizedPostalCode,
            normalizedCountry: normalizedCountry,
            latitude: placemark.location?.coordinate.latitude,
            longitude: placemark.location?.coordinate.longitude,
            confidence: confidence
        )
    }

    private func buildAddressString(from address: PostalAddress) -> String {
        // Example: "88 Avenue des Eperviers, 1150 Brussels, Belgium"
        [
            address.street,
            address.postalCode.isEmpty && address.city.isEmpty
                ? nil
                : "\(address.postalCode) \(address.city)".trimmingCharacters(in: .whitespaces),
            address.country
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func geocode(addressString: String) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(addressString) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    private func computeConfidence(
        input: PostalAddress,
        placemarkStreet: String?,
        placemarkPostalCode: String?,
        placemarkCity: String?,
        placemarkCountry: String?
    ) -> Double {
        var score = 0.0

        // Country match
        if let pCountry = placemarkCountry,
           normalize(input.country) == normalize(pCountry) {
            score += 0.2
        }

        // Postal code match
        if let pPostal = placemarkPostalCode,
           normalize(input.postalCode) == normalize(pPostal) {
            score += 0.4
        }

        // City match (diacritic-insensitive)
        if let pCity = placemarkCity,
           normalize(input.city) == normalize(pCity) {
            score += 0.2
        }

        // Street match (diacritic-insensitive)
        if let pStreet = placemarkStreet,
           normalize(input.street) == normalize(pStreet) {
            score += 0.2
        }

        return min(score, 1.0)
    }

    private func normalize(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

