//
//  NoChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct NoChoiceView: View {
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.ckrMint)

            Text("Did you complete the challenge?")
                .font(.custom("BaksoSapi", size: 18))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onSubmit()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("I've done it!")
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ckrMint)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
    }
}
