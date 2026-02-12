//
//  SingleAnswerView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct SingleAnswerView: View {
    @State private var answer: String = ""
    @State private var isEditing = false
    let isSubmitting: Bool
    let onSubmit: (String) -> Void

    var trimmedAnswer: String { answer.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 20) {
            // Tappable placeholder — opens sheet for typing
            Button { isEditing = true } label: {
                Text(trimmedAnswer.isEmpty ? "Tap here to write your answer..." : trimmedAnswer)
                    .font(.system(size: 17))
                    .foregroundStyle(trimmedAnswer.isEmpty ? .secondary : .primary)
                    .lineLimit(1...3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button("SUBMIT YOUR NAME") {
                onSubmit(trimmedAnswer)
            }
            .submitButton(isEnabled: !trimmedAnswer.isEmpty, isLoading: isSubmitting)
            .disabled(trimmedAnswer.isEmpty || isSubmitting)
        }
        .sheet(isPresented: $isEditing) {
            SingleAnswerInputSheet(answer: $answer)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Input Sheet

private struct SingleAnswerInputSheet: View {
    @Binding var answer: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Type your creative name here...", text: $answer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding()
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("Ta réponse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { isFocused = true }
    }
}
