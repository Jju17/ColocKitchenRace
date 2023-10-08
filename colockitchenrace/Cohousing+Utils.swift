//
//  Cohousing+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import Foundation

extension Cohousing {
    var contactUser: User? {
        self.users.first { $0.isContactUser }
    }
}
