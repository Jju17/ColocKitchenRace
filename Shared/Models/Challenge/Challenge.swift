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
    var title: String
    var startDate: Date
    var endDate: Date
    var body: String
    var content: ChallengeContent

//    func toChallengeDTO() -> ChallengeDTO {
//        ChallengeDTO(
//            id: id,
//            title: title,
//            startTimestamp: Timestamp(date: startDate),
//            endTimestamp: Timestamp(date: endDate),
//            body: body,
//            type:
//        )
//    }
}

extension Challenge {
    static var empty: Challenge {
        return Challenge(id: UUID(),
                         title: "",
                         startDate: Date(),
                         endDate: Date(),
                         body: "",
                         content: .noChoice
        )
    }
}

extension Challenge {
    static var mock: Challenge {
        return Challenge(id: UUID(),
                         title: "The Challenge",
                         startDate: Date(),
                         endDate: Date().addingTimeInterval(86400),
                         body: "This is a new challenge",
                         content: .noChoice
        )
    }

    static var mockList: [Challenge] {
        return [
            Challenge(
                id: UUID(),
                title: "First to register !",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 4),
                body: "Register to the next edition of coloc kitchen race 3, 2, 1, go !",
                content: .noChoice
            ),
            Challenge(
                id: UUID(),
                title: "Best cohouse name",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .noChoice
            ),
            Challenge(
                id: UUID(),
                title: "Young you",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Golden globe",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .multipleChoice(MultipleChoiceContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best dressing",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best cohouse picture",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Enigma",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .singleAnswer(SingleAnswerContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best pyramid",
                startDate: Date.from(year: 2025, month: 3, day: 1),
                endDate: Date.from(year: 2025, month: 3, day: 6),
                body: "Description",
                content: .picture(PictureContent())
            )
        ]
    }
}
