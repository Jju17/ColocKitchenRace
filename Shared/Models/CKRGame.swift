//
//  CKRGame.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import Foundation

struct CKRGame: Equatable, Hashable, Identifiable, Codable {
    var id: UUID = UUID()
    var editionNumber: Int = 1
    var nextGameDate: Date
    var registrationDeadline: Date
    var maxParticipants: Int = 100
    var publishedTimestamp: Date = Date()
    var participantsID: [String] = [] // Cohouse ID
    var matchedGroups: [[String]]?     // Groups of 4 cohouse IDs after matching
    var matchedAt: Date?               // Timestamp of last matching

    /// Whether registrations are still open (deadline not passed and capacity not reached).
    var isRegistrationOpen: Bool {
        Date() < registrationDeadline && participantsID.count < maxParticipants
    }

    /// Number of remaining spots.
    var remainingSpots: Int {
        max(0, maxParticipants - participantsID.count)
    }
}
