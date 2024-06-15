//
//  Logger+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import Foundation
import os

extension Logger {
    static var authLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Auth")
}
