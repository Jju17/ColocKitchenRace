//
//  ChallengeDTO.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 11/05/2025.
//

import Foundation
import FirebaseFirestore

struct ChallengeDTO: Equatable, Hashable, Codable, Identifiable {
    let id: UUID
    var title: String
    var startTimestamp: Timestamp
    var endTimestamp: Timestamp
    var body: String
    var type: ChallengeType

    func toChallenge() -> Challenge {
        Challenge(
            id: id,
            title: title,
            startDate: startTimestamp.dateValue(),
            endDate: endTimestamp.dateValue(),
            body: body,
            content: type.toContent()
        )
    }
}

extension ChallengeDTO {
    static var empty: ChallengeDTO {
        return ChallengeDTO(id: UUID(),
                            title: "",
                            startTimestamp: Timestamp(),
                            endTimestamp: Timestamp(),
                            body: "",
                            type: .noChoice
        )
    }

    static var mock: ChallengeDTO {
        return ChallengeDTO(
            id: UUID(),
            title: "First to register !",
            startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
            endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
            body: "Register to the next edition of coloc kitchen race.\n3, 2, 1, go !",
            type: .noChoice
        )
    }

    static var mockList: [ChallengeDTO] {
        return [
            ChallengeDTO(
                id: UUID(),
                title: "First to register !",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Register to the next edition of coloc kitchen race 3, 2, 1, go !",
                type: .noChoice
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Best cohouse name",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .noChoice
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Young you",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .picture
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Golden globe",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .multipleChoice
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Best dressing",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .picture
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Best cohouse picture",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .picture
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Enigma",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .singleAnswer
            ),
            ChallengeDTO(
                id: UUID(),
                title: "Best pyramid",
                startTimestamp: Timestamp(seconds: 1721901600, nanoseconds: 0),
                endTimestamp: Timestamp(seconds: 1721988000, nanoseconds: 0),
                body: "Description",
                type: .picture
            ),
        ]
    }
}
