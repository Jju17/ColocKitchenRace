//
//  Challenge.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI
import FirebaseFirestore

enum ChallengeState: String {
    case done = "Done"
    case ongoing = "Ongoing"
    case notStarted = "Not started"
}

struct Challenge: Equatable, Hashable, Codable, Identifiable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var body: String
    var content: ChallengeContent
}

extension Challenge {
    var state: ChallengeState {
        if Date() > endDate {
            return .done
        } else if Date() < startDate {
            return .notStarted
        } else {
            return .ongoing
        }
    }

    var isActive: Bool {
        if self.startDate < Date() && self.endDate > Date() {
            return true
        } else {
            return false
        }
    }

    var stateColor: Color {
        switch state {
            case .done:
                return .red
            case .ongoing:
                return .green
            case .notStarted:
                return .orange
        }
    }

    static var empty: Challenge {
        return Challenge(id: UUID(),
                         title: "",
                         startDate: Date(),
                         endDate: Date(),
                         body: "",
                         content: .noChoice(NoChoiceContent())
        )
    }
}

extension Challenge {
    static var mock: Challenge {
        return Challenge(
            id: UUID(),
            title: "Community Kickoff Challenge",
            startDate: Date.from(year: 2024, month: 5, day: 14, hour: 9), // Today, May 14, 2025
            endDate: Date.from(year: 2026, month: 5, day: 15, hour: 23), // Tomorrow
            body: "Join the coloc kitchen race by registering your cohouse today!",
            content: .noChoice(NoChoiceContent())
        )
    }

    static var mockList: [Challenge] {
        return [
            Challenge(
                id: UUID(),
                title: "First to Register!",
                startDate: Date.from(year: 2024, month: 3, day: 1, hour: 8),
                endDate: Date.from(year: 2026, month: 3, day: 4, hour: 23),
                body: "Be the first cohouse to register for the Coloc Kitchen Race 2025! Submit your registration to participate.",
                content: .noChoice(NoChoiceContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best Cohouse Name",
                startDate: Date.from(year: 2024, month: 3, day: 10, hour: 9),
                endDate: Date.from(year: 2026, month: 3, day: 15, hour: 23),
                body: "Submit the most creative name for your cohouse. The most unique and catchy name wins!",
                content: .noChoice(NoChoiceContent())
            ),
            Challenge(
                id: UUID(),
                title: "Young You",
                startDate: Date.from(year: 2024, month: 4, day: 10, hour: 10),
                endDate: Date.from(year: 2026, month: 4, day: 17, hour: 23),
                body: "Share a fun throwback photo of your cohouse members from their younger days!",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Golden Globe Trivia",
                startDate: Date.from(year: 2024, month: 4, day: 20, hour: 12),
                endDate: Date.from(year: 2026, month: 5, day: 5, hour: 23),
                body: "Test your movie knowledge! Answer these questions about the Golden Globe Awards.",
                content: .multipleChoice(MultipleChoiceContent(
                    choices: ["Titanic", "La La Land", "The Godfather", "Avatar"],
                    correctAnswerIndex: 2,
                    allowMultipleSelection: false,
                    shuffleAnswers: true
                ))
            ),
            Challenge(
                id: UUID(),
                title: "Best Dressing",
                startDate: Date.from(year: 2024, month: 4, day: 15, hour: 9),
                endDate: Date.from(year: 2026, month: 4, day: 25, hour: 23),
                body: "Show off your cohouse's best outfit! Submit a photo of your most stylish look.",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best Cohouse Picture",
                startDate: Date.from(year: 2024, month: 5, day: 1, hour: 8),
                endDate: Date.from(year: 2026, month: 5, day: 15, hour: 23),
                body: "Capture the spirit of your cohouse with a group photo in your shared space!",
                content: .picture(PictureContent())
            ),
            Challenge(
                id: UUID(),
                title: "Enigma",
                startDate: Date.from(year: 2024, month: 5, day: 5, hour: 10),
                endDate: Date.from(year: 2026, month: 5, day: 12, hour: 23),
                body: "Solve this riddle: What has keys but can't open locks? Submit your answer!",
                content: .singleAnswer(SingleAnswerContent())
            ),
            Challenge(
                id: UUID(),
                title: "Best Pyramid",
                startDate: Date.from(year: 2024, month: 5, day: 20, hour: 9),
                endDate: Date.from(year: 2026, month: 5, day: 27, hour: 23),
                body: "Build a creative human pyramid with your cohouse and share the photo!",
                content: .picture(PictureContent())
            )
        ]
    }
}
