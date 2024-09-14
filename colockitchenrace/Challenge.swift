//
//  Challenge.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import Foundation
import FirebaseFirestore

struct Challenge: Equatable, Hashable, Codable, Identifiable {
    let id: UUID
    let title: String
    let startTimestamp: Timestamp
    let endTimestamp: Timestamp
    let body: String
    let type: ChallengeType
}

enum ChallengeType: Codable {
    case picture
    case multipleChoice
    case singleAnswer
    case noChoice
}

extension Challenge {
    static var mock: Challenge {
        return Challenge(
            id: UUID(),
            title: "First to register !",
            startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
            endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
            body: "Register to the next edition of coloc kitchen race.\n3, 2, 1, go !",
            type: .noChoice
        )
    }

    static var mockList: [Challenge] {
        return [
            Challenge(
                id: UUID(),
                title: "First to register !",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Register to the next edition of coloc kitchen race 3, 2, 1, go !",
                type: .noChoice
            ),
            Challenge(
                id: UUID(),
                title: "Best cohouse name",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .noChoice
            ),
            Challenge(
                id: UUID(),
                title: "Young you",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .picture
            ),
            Challenge(
                id: UUID(),
                title: "Golden globe",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .multipleChoice
            ),
            Challenge(
                id: UUID(),
                title: "BEst dressing",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .picture
            ),
            Challenge(
                id: UUID(),
                title: "Best cohouse picture",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .picture
            ),
            Challenge(
                id: UUID(),
                title: "Enigma",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .singleAnswer
            ),
            Challenge(
                id: UUID(),
                title: "Best pyramid",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Descritpion",
                type: .picture
            ),
        ]
    }
}
