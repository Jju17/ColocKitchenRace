//
//  ConfettiCannon.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 07/11/2025.
//

import SwiftUI

struct ConfettiCannon: View {
    @State private var fire = false
    
    var body: some View {
        ZStack {
            if fire {
                ConfettiView()
            }
        }
        .onAppear {
            fire = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                fire = false
            }
        }
    }
}

struct ConfettiView: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<50) { i in
                Rectangle()
                    .fill([.red, .blue, .green, .yellow, .purple].randomElement()!)
                    .frame(width: 10, height: 30)
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .position(
                        x: CGFloat.random(in: 0...proxy.size.width),
                        y: CGFloat.random(in: -100...proxy.size.height)
                    )
                    .animation(
                        .linear(duration: Double.random(in: 2...4))
                        .repeatCount(1),
                        value: true
                    )
            }
        }
    }
}
