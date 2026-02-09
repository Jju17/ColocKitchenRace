//
//  AddressValidatorClient.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import ComposableArchitecture
import FirebaseFunctions

// MARK: - Result Type

enum AddressValidationResult: Equatable {
    case invalidSyntax
    case notFound
    case lowConfidence(ValidatedAddress)
    case valid(ValidatedAddress)
}

// MARK: - Client Interface

@DependencyClient
struct AddressValidatorClient {
    var validate: @Sendable (_ address: PostalAddress) async -> AddressValidationResult = { _ in .notFound }
}

// MARK: - Implementations

extension AddressValidatorClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        validate: { address in
            // Quick offline syntax check
            let trimmedStreet = address.street.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCity = address.city.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedStreet.count >= 5, trimmedCity.count >= 2 else {
                return .invalidSyntax
            }

            // Call the validateAddress Cloud Function (Nominatim / OpenStreetMap)
            let functions = Functions.functions(region: "europe-west1")
            let callable = functions.httpsCallable("validateAddress")

            let data: [String: Any] = [
                "street": address.street,
                "city": address.city,
                "postalCode": address.postalCode,
                "country": address.country,
            ]

            do {
                let result = try await callable.call(data)

                guard let dict = result.data as? [String: Any],
                      let isValid = dict["isValid"] as? Bool
                else {
                    return .notFound
                }

                guard isValid else {
                    return .notFound
                }

                let normalizedStreet = dict["normalizedStreet"] as? String
                let normalizedCity = dict["normalizedCity"] as? String
                let normalizedPostalCode = dict["normalizedPostalCode"] as? String
                let normalizedCountry = dict["normalizedCountry"] as? String
                let latitude = dict["latitude"] as? Double
                let longitude = dict["longitude"] as? Double

                let validated = ValidatedAddress(
                    input: address,
                    normalizedStreet: normalizedStreet,
                    normalizedCity: normalizedCity,
                    normalizedPostalCode: normalizedPostalCode,
                    normalizedCountry: normalizedCountry,
                    latitude: latitude,
                    longitude: longitude,
                    confidence: computeConfidence(
                        input: address,
                        normalizedStreet: normalizedStreet,
                        normalizedCity: normalizedCity,
                        normalizedPostalCode: normalizedPostalCode,
                        normalizedCountry: normalizedCountry
                    )
                )

                return validated.confidence >= 0.8
                    ? .valid(validated)
                    : .lowConfidence(validated)
            } catch {
                return .notFound
            }
        }
    )

    // MARK: Test

    static let testValue = Self(
        validate: { _ in .notFound }
    )

    // MARK: Preview

    static let previewValue = Self(
        validate: { address in
            .valid(ValidatedAddress(
                input: address,
                normalizedStreet: address.street,
                normalizedCity: address.city,
                normalizedPostalCode: address.postalCode,
                normalizedCountry: address.country,
                latitude: 50.8503,
                longitude: 4.3517,
                confidence: 0.95
            ))
        }
    )

    // MARK: - Private Helpers

    private static func normalize(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    private static func computeConfidence(
        input: PostalAddress,
        normalizedStreet: String?,
        normalizedCity: String?,
        normalizedPostalCode: String?,
        normalizedCountry: String?
    ) -> Double {
        var score = 0.0

        if let pCountry = normalizedCountry,
           normalize(input.country) == normalize(pCountry) {
            score += 0.2
        }

        if let pPostal = normalizedPostalCode,
           normalize(input.postalCode) == normalize(pPostal) {
            score += 0.4
        }

        if let pCity = normalizedCity,
           normalize(input.city) == normalize(pCity) {
            score += 0.2
        }

        if let pStreet = normalizedStreet,
           normalize(input.street) == normalize(pStreet) {
            score += 0.2
        }

        return min(score, 1.0)
    }
}

// MARK: - Registration

extension DependencyValues {
    var addressValidatorClient: AddressValidatorClient {
        get { self[AddressValidatorClient.self] }
        set { self[AddressValidatorClient.self] = newValue }
    }
}
