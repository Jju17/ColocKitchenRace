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
                .foregroundColor(.green)

            Text("I’ve done it!")
                .font(.title2.bold())

            Button("MARK AS DONE") {
                onSubmit()
            }
            .submitButton(isLoading: isSubmitting)
            .disabled(isSubmitting)
        }
    }
}
