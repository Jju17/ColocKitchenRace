//
//  PostalAddress.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/02/2024.
//

import Foundation

struct PostalAddress: Equatable, Hashable, Codable {
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var country: String = "Belgique"
}

extension PostalAddress {
    /// Returns a copy with all fields trimmed and lowercased (for case-insensitive Firestore queries).
    var lowercased: PostalAddress {
        PostalAddress(
            street: street.trimmingCharacters(in: .whitespaces).lowercased(),
            city: city.trimmingCharacters(in: .whitespaces).lowercased(),
            postalCode: postalCode.trimmingCharacters(in: .whitespaces).lowercased(),
            country: country.trimmingCharacters(in: .whitespaces).lowercased()
        )
    }

    static var mock: PostalAddress {
        PostalAddress(street: "88 Avenue des Eperviers", city: "Brussels", postalCode: "1150", country: "Belgique")
    }
}
