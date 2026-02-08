//
//  AddressValidatorClient.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import Foundation
import CoreLocation
import ComposableArchitecture

enum AddressValidationResult: Equatable {
    case invalidSyntax
    case notFound
    case lowConfidence(ValidatedAddress)
    case valid(ValidatedAddress)
}

@DependencyClient
struct AddressValidatorClient {
    var validate: @Sendable (_ address: PostalAddress) async -> AddressValidationResult = { _ in .notFound }
}

extension AddressValidatorClient: DependencyKey {
    static let liveValue: AddressValidatorClient = .init(
        validate: { address in
            // 1. Validation offline
            let syntaxValidator = AddressSyntaxValidator()
            guard syntaxValidator.isValid(address) else {
                return .invalidSyntax
            }

            // 2. Validation via geocoder
            let geocoderValidator = AddressGeocoderValidator()

            do {
                guard let validated = try await geocoderValidator.validate(address: address) else {
                    return .notFound
                }

                if validated.confidence >= 0.8 {
                    return .valid(validated)
                } else {
                    return .lowConfidence(validated)
                }
            } catch {
                return .notFound
            }
        }
    )

    static let testValue = Self(
        validate: { _ in .notFound }
    )

    static var previewValue: AddressValidatorClient {
        .init(
            validate: { address in
                let validated = ValidatedAddress(
                    input: address,
                    normalizedStreet: address.street,
                    normalizedCity: address.city,
                    normalizedPostalCode: address.postalCode,
                    normalizedCountry: address.country,
                    latitude: 50.8503,
                    longitude: 4.3517,
                    confidence: 0.95
                )
                return .valid(validated)
            }
        )
    }
}

extension DependencyValues {
    var addressValidatorClient: AddressValidatorClient {
        get { self[AddressValidatorClient.self] }
        set { self[AddressValidatorClient.self] = newValue }
    }
}
