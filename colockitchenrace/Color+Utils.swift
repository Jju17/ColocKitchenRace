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
}

extension Color {
    static var CKRRandom: Color {
        let colors = [CKRBlue, CKRGreen, CKRPurple, CKRYellow]
        return colors.randomElement()!
    }
}
