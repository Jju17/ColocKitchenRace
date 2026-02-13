//
//  CKRMyPlanning.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 13/02/2026.
//

import Foundation

/// The personalized CKR evening planning for a specific cohouse.
/// Returned by the `getMyPlanning` Cloud Function after the admin reveals.
struct CKRMyPlanning: Equatable, Codable {
    var apero: PlanningStep
    var diner: PlanningStep
    var party: PartyInfo
}

/// One step of the evening (apéro or dîner).
struct PlanningStep: Equatable, Codable, Identifiable {
    var id: String { "\(role.rawValue)-\(cohouseName)" }
    var role: StepRole                  // Are we hosting or visiting?
    var cohouseName: String             // Name of the other cohouse
    var address: String                 // Address where this step takes place
    var hostPhone: String?              // Phone of the host cohouse contact
    var visitorPhone: String?           // Phone of the visiting cohouse contact
    var totalPeople: Int                // Total people at this step (both cohouses)
    var dietarySummary: [String: Int]   // e.g. ["Végétarien": 2, "Sans gluten": 1]
    var startTime: Date
    var endTime: Date
}

/// Whether the cohouse hosts (stays home) or visits (goes to the other cohouse).
enum StepRole: String, Codable, Equatable {
    case host       // The other cohouse comes to our place
    case visitor    // We go to the other cohouse's place
}

/// Global party info (same for everyone).
struct PartyInfo: Equatable, Codable {
    var name: String
    var address: String
    var startTime: Date
    var endTime: Date
    var note: String?
}
