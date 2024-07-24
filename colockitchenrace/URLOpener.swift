//
//  URLOpener.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI

class URLOpener {
    static func open(urlString: String?, completion: ((Bool) -> Void)? = nil) {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            completion?(false)
            return
        }
        UIApplication.shared.open(url, completionHandler: completion)
    }
}
