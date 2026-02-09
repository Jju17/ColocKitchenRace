//
//  FirestoreCohouse.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 14/07/2024.
//

import ComposableArchitecture
import Foundation

struct FirestoreCohouse: Equatable, Hashable, Codable {
    var id: UUID
    var name: String
    var nameLower: String?
    var address: PostalAddress
    var addressLower: PostalAddress?
    var code: String
}

extension FirestoreCohouse {
    func toCohouseObject(with users: [CohouseUser]) -> Cohouse {
        return Cohouse(
            id: self.id,
            name: self.name,
            address: self.address,
            code: self.code,
            users: IdentifiedArray(uniqueElements: users)
        )
    }
}

extension FirestoreCohouse {
    static var mock: FirestoreCohouse {
        return FirestoreCohouse(
            id: UUID(),
            name: "Zone 88",
            nameLower: "zone 88",
            address: .mock,
            addressLower: PostalAddress.mock.lowercased,
            code: "1234"
        )
    }
}
