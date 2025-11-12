//
//  SubmitButtonStyle.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 07/11/2025.
//

import SwiftUI

struct SubmitButtonStyle: ViewModifier {
    let isEnabled: Bool
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? Color.green : Color.gray.opacity(0.5))
            )
            .overlay(
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.horizontal)
                .foregroundStyle(.white)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(isLoading ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLoading)
    }
}

extension View {
    func submitButton(isEnabled: Bool = true, isLoading: Bool = false) -> some View {
        self.modifier(SubmitButtonStyle(isEnabled: isEnabled, isLoading: isLoading))
    }
}
