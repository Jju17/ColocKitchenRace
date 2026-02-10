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

struct CKRGame: Equatable, Hashable, Identifiable, Codable {
    var id: UUID = UUID()
    var editionNumber: Int = 1
    var startCKRCountdown: Date
    var nextGameDate: Date
    var registrationDeadline: Date
    var maxParticipants: Int = 100
    var publishedTimestamp: Date = Date()
    var participantsID: [String] = []       // Cohouse IDs
    var matchedGroups: [MatchedGroup]?      // Groups of 4 cohouse IDs after matching
    var matchedAt: Date?                    // Timestamp of last matching

    /// Whether registrations are still open (deadline not passed and capacity not reached).
    var isRegistrationOpen: Bool {
        Date() < registrationDeadline && participantsID.count < maxParticipants
    }

    /// Number of remaining spots.
    var remainingSpots: Int {
        max(0, maxParticipants - participantsID.count)
    }

    /// Whether the countdown has started (deletion no longer allowed without a real admin).
    var hasCountdownStarted: Bool {
        Date() >= startCKRCountdown
    }
}
