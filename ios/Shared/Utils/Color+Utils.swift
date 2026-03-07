//
//  Color+Utils.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

extension Color {
    @MainActor static var ckrRandom: Color {
        let colors: [Color] = [.ckrMint, .ckrSky, .ckrLavender, .ckrCoral, .ckrGold].filter { $0 != lastCKRColor }
        let randomColor = colors.randomElement() ?? .ckrMint
        Color.lastCKRColor = randomColor
        return randomColor
    }

    @MainActor static var lastCKRColor: Color = .ckrMint
}
