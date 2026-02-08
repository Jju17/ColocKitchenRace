//
//  User.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

enum Gender: String, CaseIterable, Codable {
    case male, female, other
}

struct User: Equatable, Hashable, Identifiable, Codable {
    var id: UUID
    var authId: String = ""
    var isSubscribeToNews: Bool = false
    var firstName: String = ""
    var lastName: String = ""
    var phoneNumber: String?
    var email: String?
    var dietaryPreferences: Set<DietaryPreference> = []
    var gender: Gender?
    var fcmToken: String?
    var cohouseId: String?
}

extension User {
    var fullName: String {
        "\(firstName) \(lastName)"
    }

    func toCohouseUser(isAdmin: Bool = false) -> CohouseUser {
        CohouseUser(id: UUID(), isAdmin: isAdmin, surname: fullName, userId: id.uuidString)
    }
}

extension User {
    static var emptyUser: User {
        User(id: .init())
    }

    static var mockUser: User {
        User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "+32 123 45 67 89", email: "blob@example.com", dietaryPreferences: [.lactoseFree])
    }

    static var mockUser2: User {
        User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Sr", phoneNumber: "+32 123 45 67 90", email: "blob.sr@example.com", dietaryPreferences: [.lactoseFree, .glutenFree])
    }

    static var mockUsers: [User] {
        [
            User(id: UUID(), firstName: "Alice", lastName: "Dupont", phoneNumber: "+32 400 00 00 01", email: "alice@example.com", dietaryPreferences: []),
            User(id: UUID(), firstName: "Bob", lastName: "Martin", phoneNumber: "+32 400 00 00 02", email: "bob@example.com", dietaryPreferences: []),
            User(id: UUID(), firstName: "Charlie", lastName: "Lambert", phoneNumber: "+32 400 00 00 03", email: "charlie@example.com", dietaryPreferences: [.lactoseFree, .glutenFree]),
            User(id: UUID(), firstName: "Diana", lastName: "Janssen", phoneNumber: "+32 400 00 00 04", email: "diana@example.com", dietaryPreferences: []),
            User(id: UUID(), firstName: "Eve", lastName: "Peeters", dietaryPreferences: [.lactoseFree]),
            User(id: UUID(), firstName: "Frank", lastName: "Claes", phoneNumber: "+32 400 00 00 06", email: "frank@example.com", dietaryPreferences: [.glutenFree]),
            User(id: UUID(), firstName: "Grace", lastName: "Dubois", phoneNumber: "+32 400 00 00 07", dietaryPreferences: [.glutenFree]),
            User(id: UUID(), firstName: "Hugo", lastName: "Lemaire", email: "hugo@example.com", dietaryPreferences: []),
        ]
    }
}
