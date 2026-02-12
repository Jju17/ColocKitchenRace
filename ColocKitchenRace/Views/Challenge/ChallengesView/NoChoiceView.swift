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
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.ckrMint)

            Text("I've done it!")
                .font(.custom("BaksoSapi", size: 20))
                .fontWeight(.bold)

            Button("MARK AS DONE") {
                onSubmit()
            }
            .submitButton(isLoading: isSubmitting)
            .disabled(isSubmitting)
        }
    }
}
