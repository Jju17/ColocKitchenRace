//
//  Error+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 22/07/2024.
//

import Foundation

extension Error {
    static var standardError: Error {
        StandardError()
    }
}

struct StandardError: Error {}
