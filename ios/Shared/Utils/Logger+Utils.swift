//
//  Logger+Utils.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import Foundation
import os

extension Logger {
    static let authLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "Auth")
    static let challengeLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "Challenge")
    static let challengeResponseLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "ChallengeResponseClient")
    static let cohouseLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "Cohouse")
    static let globalLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "Global")
    static let newsLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "News")
    static let ckrLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "CKR")
    static let paymentLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "Payment")
    static let storageLog = Self(subsystem: Bundle.main.bundleIdentifier ?? "dev.rahier.colocskitchenrace", category: "StorageClient")
}
