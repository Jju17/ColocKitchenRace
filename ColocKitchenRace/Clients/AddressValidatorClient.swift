//
//  AddressValidatorClient.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import ComposableArchitecture
import CoreLocation

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
            // 1. Offline syntax check
            let syntaxValidator = AddressSyntaxValidator()
            guard syntaxValidator.isValid(address) else {
                return .invalidSyntax
            }

            // 2. Geocoder validation
            let geocoderValidator = AddressGeocoderValidator()

            do {
                guard let validated = try await geocoderValidator.validate(address: address) else {
                    return .notFound
                }
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
}

// MARK: - Registration

extension DependencyValues {
    var addressValidatorClient: AddressValidatorClient {
        get { self[AddressValidatorClient.self] }
        set { self[AddressValidatorClient.self] = newValue }
    }
}
