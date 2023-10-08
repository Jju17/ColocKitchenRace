//
//  Cohousing.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

struct Cohousing: Equatable, Hashable {
    var id: UUID
    var name: String
    var users: [User]
    var address: String
    var postCode: String
    var city: String
}

extension Cohousing {
    static var mock: Cohousing {
        return Cohousing(id: UUID(), name: "Zone 88", users: User.mockUsers, address: "88 Avenue des Eperviers", postCode: "1150", city: "Woluwe-Saint-Pierre")
    }
}
