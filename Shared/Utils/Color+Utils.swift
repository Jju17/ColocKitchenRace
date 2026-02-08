//
//  Color+Utils.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import SwiftUI

extension Color {
    static let CKRBlue = Color("CKRBlue")
    static let CKRGreen = Color("CKRGreen")
    static let CKRPurple = Color("CKRPurple")
    static let CKRYellow = Color("CKRYellow")

    static var CKRRandom: Color {
        let colors = [CKRBlue, CKRGreen, CKRPurple, CKRYellow].filter { $0 != lastCKRColor }
        let randomColor = colors.randomElement() ?? CKRBlue
        Color.lastCKRColor = randomColor
        return randomColor
    }

    static var lastCKRColor: Color = CKRBlue
}
