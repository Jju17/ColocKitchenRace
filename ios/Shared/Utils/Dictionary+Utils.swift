//
//  Dictionary+Utils.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import Foundation

extension Dictionary {
    var toQueryString: String {
        map {
            let key = "\($0.key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\($0.key)"
            let value = "\($0.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\($0.value)"
            return "\(key)=\(value)"
        }.joined(separator: "&")
    }
}
