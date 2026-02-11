//
//  CohouseType.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 11/02/2026.
//

import Foundation

enum CohouseType: String, Codable, CaseIterable, Identifiable, Hashable {
    case mixed = "mixed"
    case girls = "girls"
    case boys = "boys"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mixed: return String(localized: "Mixed")
        case .girls: return String(localized: "Girls")
        case .boys: return String(localized: "Boys")
        }
    }
}
