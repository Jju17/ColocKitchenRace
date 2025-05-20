//
//  CKRGame.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import Foundation

struct CKRGame: Equatable, Hashable, Identifiable, Codable {
    var id: UUID = UUID()
    var nextGameDate: Date
    var publishedTimestamp: Date = Date()
    var participantsID: [String] = [] // Cohouse ID
}
