//
//  ZoomableImageView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 30/05/2025.
//

import SwiftUI

struct ZoomableImageView: View {
    let image: UIImage

    @State private var baseScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    @GestureState private var zoomFactor: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(min(max(currentScale, 1.0), 4.0))
            .offset(x: offset.width + dragOffset.width,
                    y: offset.height + dragOffset.height)
            .gesture(combinedGesture)
            .overlay(resetButton, alignment: .bottomTrailing)
    }

    private var combinedGesture: some Gesture {
        MagnificationGesture()
            .updating($zoomFactor) { value, state, _ in state = value }
            .onChanged { value in currentScale = baseScale * value }
            .onEnded { value in
                baseScale *= value
                currentScale = baseScale
                if baseScale <= 1.05 { withAnimation { resetTransform() } }
            }
            .simultaneously(with:
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                        if currentScale <= 1.05 {
                            withAnimation { offset = .zero }
                        }
                    }
            )
    }

    private var resetButton: some View {
        Button {
            withAnimation(.spring()) { resetTransform() }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .padding()
    }

    private func resetTransform() {
        baseScale = 1.0
        currentScale = 1.0
        offset = .zero
    }
}
