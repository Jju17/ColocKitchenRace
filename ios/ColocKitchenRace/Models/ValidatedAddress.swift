//
//  ValidatedAddress.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 13/11/2025.
//

import Foundation

struct ValidatedAddress: Equatable, Codable {
    let input: PostalAddress
    let normalizedStreet: String?
    let normalizedCity: String?
    let normalizedPostalCode: String?
    let normalizedCountry: String?
    let latitude: Double?
    let longitude: Double?
    let confidence: Double
}
