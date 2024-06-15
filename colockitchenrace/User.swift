//
//  User.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

struct User: Equatable, Hashable, Identifiable, Codable {
    var id: UUID
    var uid: String = ""
    var isContactUser: Bool = false
    var isSubscribeToNews: Bool = false
    var firstName: String = ""
    var lastName: String = ""
    var phoneNumber: String?
    var email: String?
    var foodIntolerences: [String] = []
    var foodIntolerence: String = ""
}

extension User {
    static var emptyUser: User {
        return User(id: .init())
    }

    static var mockUser: User {
        return User(id: UUID(), isContactUser: true, isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "123456789", email: "blob@gmail.com", foodIntolerences: ["Lactose"], foodIntolerence: "Lactose")
    }

    static var mockUser2: User {
        return User(id: UUID(), isContactUser: true, isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com", foodIntolerences: ["Lactose"], foodIntolerence: "Lactose")
    }

    static var mockUsers: [User] {
        return [
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrMartin D'Ursel", phoneNumber: "+32 456 54 36 76", email: "martin@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrVictoria De Dorlodot", phoneNumber: "", email: "victoria@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrVerena Subelack", phoneNumber: "‭+32 484 38 39 91‬", email: "verena.sb@icloud.com", foodIntolerences: ["Blé", "Poisson"]),
            User(id: UUID(), isContactUser: true, firstName: "Blob", lastName: "JrJulien Rahier", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrPierre-edouard Guillaume", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrAlexandre Karatzopoulos", phoneNumber: "+32 477 58 68 41", email: "alexandre@gmail.com", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrCyril", phoneNumber: "+32 465 50 90 90", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, firstName: "Blob", lastName: "JrLouis de Potter", email: "louis@gmail.com", foodIntolerences: [""]),
        ]
    }
}
