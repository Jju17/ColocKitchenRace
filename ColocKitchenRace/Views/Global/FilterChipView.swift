//
//  FilterChipView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 11/02/2026.
//

import SwiftUI

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("BaksoSapi", size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.ckrMint : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
