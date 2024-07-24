//
//  CKRClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

@DependencyClient
struct CKRClient {
    var register: (_ cohouse: Cohouse, _ userInfo: User) -> Void
}


extension CKRClient: DependencyKey {
    static let liveValue = Self(
        register: { cohouse, userInfo in
            let baseUrl = "https://form.typeform.com/to/UmwPg8Lr"
            var params = [String:AnyHashable]()

            if !userInfo.fullName.isEmpty {
                params.updateValue(userInfo.fullName, forKey: "name")
            }
            if let userEmail = userInfo.email {
                params.updateValue(userEmail, forKey: "email")
            }
            if let phone = userInfo.phoneNumber {
                params.updateValue(phone, forKey: "tel")
            }
            if let gender = userInfo.gender {
                params.updateValue(gender, forKey: "gender")
            }

            params.updateValue(cohouse.name, forKey: "coloc")
            params.updateValue(cohouse.address.street, forKey: "adresse")
            params.updateValue(cohouse.address.postalCode, forKey: "codepostal")
            params.updateValue(cohouse.address.city, forKey: "ville")
            params.updateValue(cohouse.totalUsers, forKey: "nbcoloc")

            let joinedParams = params.toQueryString
            let url = "\(baseUrl)#\(joinedParams)"

            URLOpener.open(urlString: url)
        }
    )

    static var previewValue: CKRClient {
        return .testValue
    }
}

extension DependencyValues {
    var ckrClient: CKRClient {
        get { self[CKRClient.self] }
        set { self[CKRClient.self] = newValue }
    }
}
