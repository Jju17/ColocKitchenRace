//
//  Collection+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 11/05/2024.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
