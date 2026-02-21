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

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(choices.enumerated()), id: \.offset) { idx, title in
                    let isSelected = selectedIndex == idx
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedIndex = idx
                        }
                    } label: {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? Color.ckrSky : Color(white: 0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.ckrSky.opacity(isSelected ? 1 : 0.3), lineWidth: 2)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
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
