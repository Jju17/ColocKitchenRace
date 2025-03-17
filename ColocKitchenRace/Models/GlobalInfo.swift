//
//  GlobalInfo.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 22/07/2024.
//

import Foundation
import FirebaseFirestore

struct GlobalInfo: Equatable, Hashable, Codable {
    var nextCKRTimestamp: Timestamp
    var publishedTimestamp: Timestamp
    var registerLink: String
}

extension GlobalInfo {
    var publishedDate: Date {
        return self.publishedTimestamp.dateValue()
    }
    var nextCKR: Date {
        return self.nextCKRTimestamp.dateValue()
    }
}
