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
        return "\(self.firstName) \(self.lastName)"
    }
}

extension User {
    static var emptyUser: User {
        return User(id: .init())
    }

    static var mockUser: User {
        return User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "123456789", email: "blob@gmail.com")
    }

    static var mockUser2: User {
        return User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com")
    }

    static var mockUsers: [User] {
        return [
            User(id: UUID(), firstName: "Blob", lastName: "JrMartin D'Ursel", phoneNumber: "+32 456 54 36 76", email: "martin@gmail.com"),
            User(id: UUID(), firstName: "Blob", lastName: "JrVictoria De Dorlodot", phoneNumber: "", email: "victoria@gmail.com"),
            User(id: UUID(), firstName: "Blob", lastName: "JrVerena Subelack", phoneNumber: "‭+32 484 38 39 91‬", email: "verena.sb@icloud.com"),
            User(id: UUID(), firstName: "Blob", lastName: "JrJulien Rahier", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com"),
            User(id: UUID(), firstName: "Blob", lastName: "JrPierre-edouard Guillaume"),
            User(id: UUID(), firstName: "Blob", lastName: "JrAlexandre Karatzopoulos", phoneNumber: "+32 477 58 68 41", email: "alexandre@gmail.com"),
            User(id: UUID(), firstName: "Blob", lastName: "JrCyril", phoneNumber: "+32 465 50 90 90"),
            User(id: UUID(), firstName: "Blob", lastName: "JrLouis de Potter", email: "louis@gmail.com"),
        ]
    }
}
