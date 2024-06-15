//
//  News.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 16/06/2024.
//

import Foundation
import FirebaseFirestore

struct News: Codable {
    var id: String
    var title: String
    var body: String
    var publicationTimestamp: Timestamp
}

extension News {
    var publicationDate: Date {
        self.publicationTimestamp.dateValue()
    }
}
