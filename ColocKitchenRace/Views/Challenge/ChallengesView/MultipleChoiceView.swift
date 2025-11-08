//
//  MultipleChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct MultipleChoiceView: View {
    let choices: [String]
    @Binding var selectedIndex: Int?
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(choices.enumerated()), id: \.offset) { idx, title in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex = idx
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedIndex == idx ? .white : .primary)
                        Spacer()
                        if selectedIndex == idx {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedIndex == idx ? Color.blue : Color(white: 0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(selectedIndex == idx ? 1 : 0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            if selectedIndex != nil {
                Button("SUBMIT YOUR ANSWER") {
                    onSubmit()
                }
                .submitButton(isEnabled: true, isLoading: isSubmitting)
                .disabled(isSubmitting)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedIndex)
    }
}
