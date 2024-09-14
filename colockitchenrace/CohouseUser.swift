//
//  CohouseUser.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/07/2024.
//

import ComposableArchitecture
import Foundation

struct CohouseUser: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var isAdmin: Bool = false
    var surname: String = ""
    var userId: String?
}

extension CohouseUser {
    var isAssignedToRealUser: Bool {
        return self.userId != nil
    }

    var isActualUser: Bool {
        @Shared(.userInfo) var userInfo
        guard let userInfo,
              let userId
        else { return false }

        return userId == userInfo.id.uuidString
    }
}

extension CohouseUser {
    static var mock: CohouseUser {
        CohouseUser(
            id: UUID(),
            isAdmin: false,
            surname: "Julien"
        )
    }

    static var mockList: [CohouseUser] {
        [
            CohouseUser(
                id: UUID(),
                isAdmin: false,
                surname: "Julien"
            ),
            CohouseUser(
                id: UUID(),
                isAdmin: false,
                surname: "Adrien"
            ),
            CohouseUser(
                id: UUID(),
                isAdmin: false,
                surname: "Martin"
            )
        ]
    }
}
