//
//  CKRGame.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import Foundation

/// A group of cohouse IDs produced by the matching algorithm.
/// Wrapped in a struct because Firestore does not support nested arrays.
struct MatchedGroup: Equatable, Hashable, Codable {
    var cohouseIds: [String]
}

/// Event time slots and party info, configured by the admin before revealing.
struct CKREventSettings: Equatable, Hashable, Codable {
    var aperoStartTime: Date
    var aperoEndTime: Date
    var dinerStartTime: Date
    var dinerEndTime: Date
    var partyStartTime: Date
    var partyEndTime: Date
    var partyAddress: String
    var partyName: String
    var partyNote: String?
}

/// Role assignment within a matched group of 4 cohouses.
///
/// Schema:
/// - Apéro: A → B (A cooks at B), C → D (C cooks at D)
/// - Dîner: C → A (C cooks at A), D → B (D cooks at B)
struct GroupPlanning: Equatable, Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var groupIndex: Int        // 1-based group number
    var cohouseA: String       // cohouseId assigned role A
    var cohouseB: String       // cohouseId assigned role B
    var cohouseC: String       // cohouseId assigned role C
    var cohouseD: String       // cohouseId assigned role D
}

struct CKRGame: Equatable, Hashable, Identifiable, Codable {
    var id: UUID = UUID()
    var editionNumber: Int = 1
    var startCKRCountdown: Date
    var nextGameDate: Date
    var registrationDeadline: Date
    var maxParticipants: Int = 100
    var pricePerPersonCents: Int = 500  // 5,00 EUR – stored in cents (Stripe convention)
    var publishedTimestamp: Date = Date()
    var cohouseIDs: [String] = []                // Registered cohouse IDs (for matching)
    var totalRegisteredParticipants: Int = 0      // Total number of individual persons registered
    var matchedGroups: [MatchedGroup]?            // Groups of 4 cohouse IDs after matching
    var matchedAt: Date?                          // Timestamp of last matching
    var eventSettings: CKREventSettings?          // Admin-configured time slots + party info
    var groupPlannings: [GroupPlanning]?           // Role assignments (A/B/C/D) per group
    var isRevealed: Bool = false                  // Whether planning is visible to users
    var revealedAt: Date?                         // Timestamp when planning was revealed

    /// Whether registrations are still open (deadline not passed and capacity not reached).
    var isRegistrationOpen: Bool {
        Date() < registrationDeadline && totalRegisteredParticipants < maxParticipants
    }

    /// Number of remaining spots (in persons).
    var remainingSpots: Int {
        max(0, maxParticipants - totalRegisteredParticipants)
    }

    /// Whether the countdown has started (deletion no longer allowed without a real admin).
    var hasCountdownStarted: Bool {
        Date() >= startCKRCountdown
    }

    /// Formatted price per person (e.g. "5,00 €").
    var formattedPricePerPerson: String {
        let euros = Double(pricePerPersonCents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_BE")
        return formatter.string(from: NSNumber(value: euros)) ?? "\(euros) €"
    }
}
