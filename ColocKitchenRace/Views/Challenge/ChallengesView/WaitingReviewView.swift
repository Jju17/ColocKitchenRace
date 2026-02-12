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
            Text("En attente de validation")
                .font(.custom("BaksoSapi", size: 18))
                .fontWeight(.semibold)
            Text("Ta réponse a été envoyée ! L'admin va la valider bientôt.")
                .font(.custom("BaksoSapi", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
