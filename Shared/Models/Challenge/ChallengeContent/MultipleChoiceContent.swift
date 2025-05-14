//
//  MultipleChoiceContent.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 11/05/2025.
//

import Foundation

struct MultipleChoiceContent: Equatable, Codable, Hashable {
    var choices: [String]
    var correctAnswerIndex: Int?
//    var allowMultipleSelection: Bool
    var shuffleAnswers: Bool

    init(choices: [String] = ["", "", "", ""], correctAnswerIndex: Int? = nil, allowMultipleSelection: Bool = false, shuffleAnswers: Bool = true) {
        self.choices = choices
        self.correctAnswerIndex = correctAnswerIndex
//        self.allowMultipleSelection = allowMultipleSelection
        self.shuffleAnswers = shuffleAnswers
    }
}
