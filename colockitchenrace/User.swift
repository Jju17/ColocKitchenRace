//
//  User.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

struct User: Equatable, Hashable, Identifiable {
    var id: UUID
    var isContactUser: Bool = false
    var displayName: String = ""
    var phoneNumber: String?
    var email: String?
    var foodIntolerences: [String] = []
}

extension User {
    static var mockUser: User {
        return User(id: UUID(), isContactUser: false, displayName: "Julien Rahier", foodIntolerences: ["Lactose"])
    }

    static var mockUsers: [User] {
        return [
            User(id: UUID(), isContactUser: false, displayName: "Martin D'Ursel", phoneNumber: "+32 456 54 36 76", email: "martin@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, displayName: "Victoria De Dorlodot", phoneNumber: "", email: "victoria@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, displayName: "Verena Subelack", phoneNumber: "‭+32 484 38 39 91‬", email: "verena.sb@icloud.com", foodIntolerences: ["Blé", "Poisson"]),
            User(id: UUID(), isContactUser: true, displayName: "Julien Rahier", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com", foodIntolerences: []),
            User(id: UUID(), isContactUser: false, displayName: "Pierre-edouard Guillaume", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, displayName: "Alexandre Karatzopoulos", phoneNumber: "+32 477 58 68 41", email: "alexandre@gmail.com", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, displayName: "Cyril", phoneNumber: "+32 465 50 90 90", foodIntolerences: ["Lactose"]),
            User(id: UUID(), isContactUser: false, displayName: "Louis de Potter", email: "louis@gmail.com", foodIntolerences: [""]),
        ]
    }
}
