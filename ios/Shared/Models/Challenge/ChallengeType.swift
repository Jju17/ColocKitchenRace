//
//  ChallengeType.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 11/05/2025.
//

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case picture
    case multipleChoice
    case singleAnswer
    case noChoice

    var id: String { self.rawValue }

    var label: String {
        switch self {
            case .picture: return "Picture"
            case .multipleChoice: return "QCM"
            case .singleAnswer: return "Free"
            case .noChoice: return "None"
        }
    }

    func toContent() -> ChallengeContent {
        switch self {
            case .picture: return .picture(PictureContent())
            case .multipleChoice: return .multipleChoice(MultipleChoiceContent())
            case .singleAnswer: return .singleAnswer(SingleAnswerContent())
            case .noChoice: return .noChoice(NoChoiceContent())
        }
    }

}
