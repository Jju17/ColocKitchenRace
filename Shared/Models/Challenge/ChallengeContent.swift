//
//  ChallengeContent.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 11/05/2025.
//

import Foundation

enum ChallengeContent: Equatable, Codable, Hashable {
    case picture(PictureContent)
    case multipleChoice(MultipleChoiceContent)
    case singleAnswer(SingleAnswerContent)
    case noChoice
}
