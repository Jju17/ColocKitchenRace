//
//  Cohouse.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

struct Cohouse: Equatable, Hashable, Codable {
    var id: UUID
    var name: String = ""
    var users: [User] = []
    var address: PostalAddress = PostalAddress()
}

extension Cohouse {
    var contactUser: User? {
        self.users.first { $0.isContactUser }
    }
}

extension Cohouse {
    static var mock: Cohouse {
        return Cohouse(id: UUID(),
                         name: "Zone 88",
                         users: User.mockUsers,
                         address: .mock)
    }
}
