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
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""
}

extension PostalAddress {
    static var mock: PostalAddress {
        PostalAddress(street: "88 Avenue des Eperviers", city: "Brussels", state: "Brussels", postalCode: "1150", country: "Belgium")
    }
}
