//
//  StartEndBadge.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI

struct StartEndBadge: View {
    enum Kind { case startsAt, endedAt }
    let kind: Kind
    let date: Date

    var body: some View {
        let (text, color): (String, Color) = {
            switch kind {
            case .startsAt:
                return ("Starts at \(date.formatted(.dateTime.day().month().hour().minute()))", .ckrSky)
            case .endedAt:
                return ("Ended at \(date.formatted(.dateTime.day().month().hour().minute()))", .secondary)
            }
        }()
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel(Text(text))
    }
}
