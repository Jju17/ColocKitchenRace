//
//  DietaryPreference.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 07/02/2026.
//

import Foundation

enum DietaryPreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case glutenFree = "gluten_free"
    case lactoseFree = "lactose_free"
    case nutFree = "nut_free"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetarian: return "Végétarien"
        case .vegan: return "Végan"
        case .glutenFree: return "Sans gluten"
        case .lactoseFree: return "Sans lactose"
        case .nutFree: return "Sans noix"
        }
    }

    var icon: String {
        switch self {
        case .vegetarian: return "🥬"
        case .vegan: return "🌱"
        case .glutenFree: return "🌾"
        case .lactoseFree: return "🥛"
        case .nutFree: return "🥜"
        }
    }
}
