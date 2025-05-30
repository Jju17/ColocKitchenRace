//
//  ValidationButton.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 30/05/2025.
//

import SwiftUI

struct ValidationButton: View {
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            action()
        }) {
            Text(label)
                .foregroundColor(color)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(isActive ? color.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
