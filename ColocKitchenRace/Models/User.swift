//
//  User.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

enum FoodIntolerences: String, CaseIterable, Codable {
    case vegetarian,
         glutenFree,
         dairyFree,
         nutsFree,
         soyFree,
         shellfishFree,
         fishFree,
         eggsFree,
         peanutsFree,
         treeNutsFree
}

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
    var foodIntolerences: [FoodIntolerences] = []
    var gender: Gender?
    var fcmToken: String?
}

extension User {
    var fullName: String {
        return "\(self.firstName) \(self.lastName)"
    }

    func toCohouseUser(isAdmin: Bool = false) -> CohouseUser {
        return CohouseUser(id: UUID(), isAdmin: isAdmin, surname: self.fullName, userId: self.id.uuidString)
    }
}

extension User {
    static var emptyUser: User {
        return User(id: .init())
    }

    static var mockUser: User {
        return User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "123456789", email: "blob@gmail.com", foodIntolerences: [.dairyFree])
    }

    static var mockUser2: User {
        return User(id: UUID(), isSubscribeToNews: true, firstName: "Blob", lastName: "Jr", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com", foodIntolerences: [.dairyFree, .glutenFree])
    }

    static var mockUsers: [User] {
        return [
            User(id: UUID(), firstName: "Blob", lastName: "JrMartin D'Ursel", phoneNumber: "+32 456 54 36 76", email: "martin@gmail.com", foodIntolerences: []),
            User(id: UUID(), firstName: "Blob", lastName: "JrVictoria De Dorlodot", phoneNumber: "", email: "victoria@gmail.com", foodIntolerences: []),
            User(id: UUID(), firstName: "Blob", lastName: "JrVerena Subelack", phoneNumber: "‭+32 484 38 39 91‬", email: "verena.sb@icloud.com", foodIntolerences: [.fishFree, .glutenFree]),
            User(id: UUID(), firstName: "Blob", lastName: "JrJulien Rahier", phoneNumber: "+32 479 50 68 41", email: "julien.rahier@gmail.com", foodIntolerences: []),
            User(id: UUID(), firstName: "Blob", lastName: "JrPierre-edouard Guillaume", foodIntolerences: [.dairyFree]),
            User(id: UUID(), firstName: "Blob", lastName: "JrAlexandre Karatzopoulos", phoneNumber: "+32 477 58 68 41", email: "alexandre@gmail.com", foodIntolerences: [.glutenFree]),
            User(id: UUID(), firstName: "Blob", lastName: "JrCyril", phoneNumber: "+32 465 50 90 90", foodIntolerences: [.glutenFree]),
            User(id: UUID(), firstName: "Blob", lastName: "JrLouis de Potter", email: "louis@gmail.com", foodIntolerences: []),
        ]
    }
}
