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
    static var challengeLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Challenge")
    static let challengeResponseLog = Self(subsystem: "com.colockitchenrace", category: "ChallengeResponseClient")
    static var cohouseLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Cohouse")
    static var globalLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Global")
    static var newsLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "News")
    static var ckrLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "CKR")
    static let storageLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "StorageClient")
}
