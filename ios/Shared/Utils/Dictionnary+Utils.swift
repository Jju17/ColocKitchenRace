//
//  Dictionary+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import Foundation

extension Dictionary {
    var toQueryString: String {
        map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }
}
