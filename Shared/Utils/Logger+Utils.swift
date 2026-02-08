//
//  Logger+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import Foundation
import os

extension Logger {
    static let authLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Auth")
    static let challengeLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Challenge")
    static let challengeResponseLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "ChallengeResponseClient")
    static let cohouseLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Cohouse")
    static let globalLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "Global")
    static let newsLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "News")
    static let ckrLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "CKR")
    static let storageLog = Self(subsystem: "com.julienrahier.colocskitchenrace", category: "StorageClient")
}
