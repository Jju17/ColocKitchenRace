//
//  Color+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

extension Color {
    static var ckrRandom: Color {
        let colors: [Color] = [.ckrMint, .ckrSky, .ckrLavender, .ckrCoral, .ckrGold].filter { $0 != lastCKRColor }
        let randomColor = colors.randomElement() ?? .ckrMint
        Color.lastCKRColor = randomColor
        return randomColor
    }

    static var lastCKRColor: Color = .ckrMint
}
