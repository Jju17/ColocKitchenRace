//
//  SingleAnswerView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct SingleAnswerView: View {
    @State private var answer: String = ""
    let isSubmitting: Bool
    let onSubmit: (String) -> Void

    var trimmedAnswer: String { answer.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 20) {
            TextField("Type your creative name here...", text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .lineLimit(3...6)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Button("SUBMIT YOUR NAME") {
                onSubmit(trimmedAnswer)
            }
            .submitButton(isEnabled: !trimmedAnswer.isEmpty, isLoading: isSubmitting)
            .disabled(trimmedAnswer.isEmpty || isSubmitting)
        }
    }
}
