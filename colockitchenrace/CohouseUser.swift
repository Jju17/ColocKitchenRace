//
//  CohouseUser.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/07/2024.
//

import Foundation

struct CohouseUser: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var isAdmin: Bool = false
    var surname: String = ""
    var userId: String?
}

extension CohouseUser {
    static var mock: CohouseUser {
        CohouseUser(
            id: UUID(),
            isAdmin: false,
            surname: "Julien"
        )
    }
}
