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
    var address: PostalAddress = PostalAddress()
    var users: [CohouseUser] = []
}

extension Cohouse {
    var joinCohouseId: String {
        let id = self.id.uuidString.split(separator: "-").first!
        return String(id)
    }

    var totalUsers: Int {
        self.users.count
    }

    var toFIRCohouse: FirestoreCohouse  {
        FirestoreCohouse(
            id: self.id,
            name: self.name,
            address: self.address
        )
    }

    var contactUser: User? {
//        self.users.first { $0.isContactUser }
        return nil
    }
}

extension Cohouse {
    static var mock: Cohouse {
        return Cohouse(id: UUID(),
                       name: "Zone 88",
                       address: .mock)
    }
}
