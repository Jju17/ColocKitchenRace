//
//  PageDotsView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 11/02/2026.
//

import SwiftUI

struct PageDotsView: View {
    let total: Int
    let currentIndex: Int

    var body: some View {
        if total > 1 {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.ckrMint : Color.secondary.opacity(0.3))
                        .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                        .animation(.easeInOut(duration: 0.2), value: currentIndex)
                }
            }
        }
    }
}
