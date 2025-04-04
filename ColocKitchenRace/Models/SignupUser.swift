//
//  SignupUser.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import Foundation

struct SignupUser: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var password: String = ""
    var phone: String = ""
}

extension SignupUser {
    func createUser(authId: String) -> User {
        User(id: UUID(),
             authId: authId,
             isSubscribeToNews: false,
             firstName: self.firstName,
             lastName: self.lastName,
             phoneNumber: nil,
             email: self.email,
             foodIntolerences: []
        )
    }
}

extension SignupUser {
    static var mock: Self {
        return Self(
            firstName: "",
            lastName: "",
            email: "",
            password: "",
            phone: ""
        )
    }
}
