//
//  FinalStatusView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI

struct FinalStatusView: View {
    let status: ChallengeResponseStatus?

    var body: some View {
        VStack(spacing: 8) {
            switch status {
            case .validated:
                Text("Response validated ✅")
                    .font(.custom("BaksoSapi", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(.ckrMint)
            case .invalidated:
                Text("Response invalidated ❌")
                    .font(.custom("BaksoSapi", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Final decision for the challenge"))
    }
}
