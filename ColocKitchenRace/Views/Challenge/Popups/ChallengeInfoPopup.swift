//
//  ChallengeInfoPopup.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 15/06/2025.
//

import SwiftUI
import MijickPopups

struct ChallengeInfoPopup: CenterPopup {
    var symbol: String
    var title: String
    var description: String
    var accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 72, height: 72)

                Image(systemName: symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            // Title
            Text(title)
                .font(.custom("BaksoSapi", size: 22))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Description
            Text(description)
                .font(.custom("BaksoSapi", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Dismiss button
            Button {
                Task { await dismissLastPopup() }
            } label: {
                Text("Ignorer")
                    .font(.custom("BaksoSapi", size: 14))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    func configurePopup(config: CenterPopupConfig) -> CenterPopupConfig {
        config
            .cornerRadius(24)
    }
}

extension ChallengeInfoPopup {
    static func makeChallengeInfoPopup(for challengeType: ChallengeType, accentColor: Color = .ckrLavender) -> any CenterPopup {
        switch challengeType {
        case .picture:
            return ChallengeInfoPopup(
                symbol: "camera.fill",
                title: "Picture Challenge",
                description: "Prends ta plus belle photo. Souris 😄",
                accentColor: accentColor
            )
        case .multipleChoice:
            return ChallengeInfoPopup(
                symbol: "list.bullet.clipboard.fill",
                title: "Multiple Choice",
                description: "Choisis la bonne réponse. Une seule tentative 🫣",
                accentColor: accentColor
            )
        case .singleAnswer:
            return ChallengeInfoPopup(
                symbol: "text.cursor",
                title: "Single Answer",
                description: "Réponse libre. Joue le jeu, sans tricher 👀",
                accentColor: accentColor
            )
        case .noChoice:
            return ChallengeInfoPopup(
                symbol: "checkmark.circle.fill",
                title: "Action Challenge",
                description: "Rien à faire ici. Valide quand c'est fait ✅",
                accentColor: accentColor
            )
        }
    }
}

#Preview {
    ChallengeInfoPopup(
        symbol: "camera.fill",
        title: "Picture Challenge",
        description: "Prends ta plus belle photo. Souris 😄",
        accentColor: .ckrCoral
    )
}
