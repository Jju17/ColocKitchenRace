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
    var shuffleAnswers: Bool

    init(choices: [String] = ["", "", "", ""], correctAnswerIndex: Int? = nil, shuffleAnswers: Bool = true) {
        self.choices = choices
        self.correctAnswerIndex = correctAnswerIndex
        self.shuffleAnswers = shuffleAnswers
    }
}
