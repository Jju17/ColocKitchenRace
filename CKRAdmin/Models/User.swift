//
//  User.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import Foundation

struct User: Equatable, Hashable, Identifiable, Codable {
    var id: UUID
    var authId: String = ""
    var isSubscribeToNews: Bool = false
    var firstName: String = ""
    var lastName: String = ""
    var phoneNumber: String?
    var email: String?
}

extension User {
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

extension User {
    static var emptyUser: User {
        User(id: .init())
    }

    static var mockUser: User {
        User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "+32 123 45 67 89", email: "blob@example.com")
    }

    static var mockUser2: User {
        User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Sr", phoneNumber: "+32 123 45 67 90", email: "blob.sr@example.com")
    }

    static var mockUsers: [User] {
        [
            User(id: UUID(), firstName: "Alice", lastName: "Dupont", phoneNumber: "+32 400 00 00 01", email: "alice@example.com"),
            User(id: UUID(), firstName: "Bob", lastName: "Martin", phoneNumber: "+32 400 00 00 02", email: "bob@example.com"),
            User(id: UUID(), firstName: "Charlie", lastName: "Lambert", phoneNumber: "+32 400 00 00 03", email: "charlie@example.com"),
            User(id: UUID(), firstName: "Diana", lastName: "Janssen", phoneNumber: "+32 400 00 00 04", email: "diana@example.com"),
            User(id: UUID(), firstName: "Eve", lastName: "Peeters"),
            User(id: UUID(), firstName: "Frank", lastName: "Claes", phoneNumber: "+32 400 00 00 06", email: "frank@example.com"),
            User(id: UUID(), firstName: "Grace", lastName: "Dubois", phoneNumber: "+32 400 00 00 07"),
            User(id: UUID(), firstName: "Hugo", lastName: "Lemaire", email: "hugo@example.com"),
        ]
    }
}
