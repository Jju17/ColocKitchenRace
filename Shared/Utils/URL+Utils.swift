//
//  URL+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 02/06/2024.
//

import Foundation

extension URL {
    static let userInfo = Self.documentsDirectory.appending(component: "userInfo.json")
    static let cohouse = Self.documentsDirectory.appending(component: "userCohouse.json")
    static let news = Self.documentsDirectory.appending(component: "news.json")
    static let challenges = Self.documentsDirectory.appending(component: "challenges.json")
    static let globalInfos = Self.documentsDirectory.appending(component: "globalInfos.json")
}
