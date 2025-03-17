//
//  MultipleChoicChallengee.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import Foundation

struct MultipleChoiceChallenge: Codable {
    var choice1: String
    var choice2: String
    var choice3: String
    var choice4: String
}

extension MultipleChoiceChallenge {
    static var mock: MultipleChoiceChallenge {
        return MultipleChoiceChallenge(
            choice1: "Choice number one",
            choice2: "Choice number two",
            choice3: "Choice number three",
            choice4: "Choice number four"
        )
    }
}
