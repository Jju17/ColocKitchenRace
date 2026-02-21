//
//  ChallengeSubmitPayload.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 11/10/2025.
//

import Foundation

public enum ChallengeSubmitPayload: Equatable {
    case picture(Data)
    case multipleChoice(Int)
    case singleAnswer(String)
    case noChoice
}

extension ChallengeSubmitPayload {
    var requiresUpload: Bool {
        if case .picture = self { return true } else { return false }
    }
}
