//
//  Cohousing.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

struct Cohousing: Equatable, Hashable, Codable {
    var id: UUID
    var name: String = ""
    var users: [User] = []
    var address: PostalAddress = PostalAddress()
}

extension Cohousing {
    static var mock: Cohousing {
        return Cohousing(id: UUID(),
                         name: "Zone 88",
                         users: User.mockUsers,
                         address: .mock)
    }
}
