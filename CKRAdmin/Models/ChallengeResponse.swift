//
//  ChallengeResponse.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 14/05/2025.
//

import Foundation
import FirebaseFirestore

// Structure for representing a challenge response
struct ChallengeResponse: Equatable, Codable, Identifiable {
    let id: UUID
    let challengeId: UUID
    let cohouseId: String
    var challengeTitle: String
    var cohouseName: String
    var content: ChallengeResponseContent
    var status: ChallengeResponseStatus
    let submissionDate: Date
}

enum ChallengeResponseContent: Equatable, Codable {
    case picture(String)
    case multipleChoice([Int])
    case singleAnswer(String)
    case noChoice
}

extension ChallengeResponseContent {
    static func fromPayload(_ payload: ChallengeSubmitPayload) -> ChallengeResponseContent {
        switch payload {
        case .picture:
            return .picture("")
        case let .multipleChoice(index):
            return .multipleChoice([index])
        case let .singleAnswer(text):
            return .singleAnswer(text)
        case .noChoice:
            return .noChoice
        }
    }

    static func fromUploadedURL(_ url: String) -> ChallengeResponseContent {
        .picture(url)
    }
}

enum ChallengeResponseStatus: String, Codable, Equatable {
    case waiting
    case validated
    case invalidated
}

extension ChallengeResponse {
    static var mock: ChallengeResponse {
        return ChallengeResponse(
            id: UUID(),
            challengeId: Challenge.mock.id, // Reference to the mock Challenge
            cohouseId: "cohouse_alpha",
            challengeTitle: "Community Kickoff Challenge",
            cohouseName: "Zone 88",
            content: .noChoice,
            status: .waiting,
            submissionDate: Date.from(year: 2025, month: 5, day: 14, hour: 20) // May 14, 2025, 8:00 PM
        )
    }

    static var mockList: [ChallengeResponse] {
        let challenges = Challenge.mockList
        let challengeIds = challenges.map { $0.id }
        return [
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[0], // "First to register !"
                cohouseId: "cohouse_alpha",
                challengeTitle: challenges[0].title,
                cohouseName: "Zone 88",
                content: .noChoice,
                status: .waiting,
                submissionDate: Date.from(year: 2025, month: 3, day: 2, hour: 10) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[2], // "Young you" (picture)
                cohouseId: "cohouse_beta",
                challengeTitle: challenges[2].title,
                cohouseName: "Beta House",
                content: .picture(""), // Placeholder for image data
                status: .validated,
                submissionDate: Date.from(year: 2025, month: 4, day: 15, hour: 14) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[3], // "Golden globe" (multipleChoice)
                cohouseId: "cohouse_gamma",
                challengeTitle: challenges[3].title,
                cohouseName: "Gamma Crew",
                content: .multipleChoice([0, 1]), // Selected choices 1 and 2
                status: .invalidated,
                submissionDate: Date.from(year: 2025, month: 5, day: 1, hour: 9) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[6], // "Enigma" (singleAnswer)
                cohouseId: "cohouse_delta",
                challengeTitle: challenges[6].title,
                cohouseName: "Delta Squad",
                content: .singleAnswer("The answer is 42"),
                status: .waiting,
                submissionDate: Date.from(year: 2025, month: 5, day: 10, hour: 16) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[4], // "Best dressing" (picture)
                cohouseId: "cohouse_epsilon",
                challengeTitle: challenges[4].title,
                cohouseName: "Epsilon Flat",
                content: .picture(""),
                status: .validated,
                submissionDate: Date.from(year: 2025, month: 4, day: 25, hour: 11) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[1], // "Best cohouse name" (noChoice)
                cohouseId: "cohouse_zeta",
                challengeTitle: challenges[1].title,
                cohouseName: "Zeta Home",
                content: .noChoice,
                status: .invalidated,
                submissionDate: Date.from(year: 2025, month: 3, day: 5, hour: 12) // During challenge
            ),
            ChallengeResponse(
                id: UUID(),
                challengeId: challengeIds[5], // "Best cohouse picture" (picture)
                cohouseId: "cohouse_eta",
                challengeTitle: challenges[5].title,
                cohouseName: "Eta Place",
                content: .picture(""),
                status: .waiting,
                submissionDate: Date.from(year: 2025, month: 5, day: 12, hour: 15) // During challenge
            )
        ]
    }
}

