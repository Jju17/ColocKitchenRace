//
//  FirestoreCohouse.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 14/07/2024.
//

import Foundation

struct FirestoreCohouse: Equatable, Hashable, Codable {
    var id: UUID
    var name: String
    var address: PostalAddress
}

extension FirestoreCohouse {
    static var mock: FirestoreCohouse {
        return FirestoreCohouse(id: UUID(),
                                name: "Zone 88",
                                address: .mock)
    }
}
