//
//  SignupField.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 16/06/2024.
//

import Foundation

enum SignupField: Int, Hashable, CaseIterable {
    case name
    case surname
    case email
    case password
    case phone

    func next() -> SignupField? {
        let allCases = SignupField.allCases
        if let currentIndex = allCases.firstIndex(of: self) {
            let nextIndex = allCases.index(after: currentIndex)
            if nextIndex < allCases.endIndex {
                return allCases[nextIndex]
            }
        }
        return nil
    }

    func previous() -> SignupField? {
        let allCases = SignupField.allCases
        if let currentIndex = allCases.firstIndex(of: self) {
            if currentIndex > allCases.startIndex {
                let previousIndex = allCases.index(before: currentIndex)
                return allCases[previousIndex]
            }
        }
        return nil
    }
}
