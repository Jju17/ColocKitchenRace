//
//  SnapPagingScrollView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 07/11/2025.
//

import SwiftUI

struct SnapPagingContainer<Content: View>: View {
    let itemWidth: CGFloat
    let spacing: CGFloat
    @Binding var currentPage: UUID?
    @ViewBuilder var content: () -> Content

    init(itemWidth: CGFloat, spacing: CGFloat = 20, currentPage: Binding<UUID?> = .constant(nil), @ViewBuilder content: @escaping () -> Content) {
        self.itemWidth = itemWidth
        self.spacing = spacing
        self._currentPage = currentPage
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    content()
                        .frame(width: itemWidth)
                }
                .padding(.horizontal, (proxy.size.width - itemWidth) / 2)
                .padding(.bottom, 16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .scrollBounceBehavior(.basedOnSize)
            .scrollPosition(id: $currentPage)
        }
        .ignoresSafeArea(.keyboard)
    }
}
