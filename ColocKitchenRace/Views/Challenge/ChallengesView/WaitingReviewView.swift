//
//  WaitingReviewView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI

struct WaitingReviewView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(.ckrGold)
            Text("Waiting for validation")
                .font(.custom("BaksoSapi", size: 18))
                .fontWeight(.semibold)
            Text("Your answer has been sent! The admin will validate it soon.")
                .font(.custom("BaksoSapi", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
