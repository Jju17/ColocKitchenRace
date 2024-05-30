//
//  SignupUser.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import Foundation

struct SignupUser: Codable {
    var name: String
    var surname: String
    var email: String
    var password: String
    var phone: String
}

extension SignupUser {
    static var mock: Self {
        return Self(
            name: "",
            surname: "",
            email: "",
            password: "",
            phone: ""
        )
    }
}
