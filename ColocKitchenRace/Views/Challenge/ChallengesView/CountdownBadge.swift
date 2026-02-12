//
//  CountdownBadge.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 18/07/2024.
//

import SwiftUI
import MijickPopups

struct CountdownBadge: View {
    let endDate: Date
    var accentColor: Color = .ckrCoral
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if let text = countdownText {
            Button {
                Task {
                    await ChallengeInfoPopup(
                        symbol: "timer",
                        title: "Temps restant",
                        description: detailedCountdown,
                        accentColor: accentColor
                    ).present()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text(text)
                        .font(.custom("BaksoSapi", size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.25))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .onReceive(timer) { _ in now = Date() }
        }
    }

    private var countdownText: String? {
        let remaining = endDate.timeIntervalSince(now)
        guard remaining > 0 else { return nil }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var detailedCountdown: String {
        let remaining = endDate.timeIntervalSince(now)
        guard remaining > 0 else { return "Ce challenge est terminé." }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        let timeString: String
        if days > 0 {
            timeString = "\(days) jour\(days > 1 ? "s" : "") et \(hours) heure\(hours > 1 ? "s" : "")"
        } else if hours > 0 {
            timeString = "\(hours) heure\(hours > 1 ? "s" : "") et \(minutes) minute\(minutes > 1 ? "s" : "")"
        } else {
            timeString = "\(minutes) minute\(minutes > 1 ? "s" : "")"
        }

        return "Il reste \(timeString) pour compléter ce challenge. Dépêche-toi ! ⏳"
    }
}
