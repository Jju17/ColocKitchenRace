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

    var body: some View {
        VStack {
            Image(systemName: self.symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40)
            Text(self.title)
                .fontWeight(.bold)
            Text(self.description)
            Spacer()
            Button {
                Task { await dismissLastPopup() }
            } label: {
                Text("Dismiss")
            }
        }
        .padding()
        .frame(maxHeight: 150)
    }

    func configurePopup(config: BottomPopupConfig) -> BottomPopupConfig {
        config
            .cornerRadius(16)
    }
}

extension ChallengeInfoPopup {
    static func makeChallengeInfoPopup(for challengeType: ChallengeType) -> any CenterPopup {
      switch challengeType {
      case .picture:
        return ChallengeInfoPopup(
          symbol: "photo.artframe",
          title: "Picture Challenge",
          description: "Prends ta plus belle photo. Souris 😄"
        )
      case .multipleChoice:
        return ChallengeInfoPopup(
          symbol: "square.grid.3x3.bottomleft.filled",
          title: "Multiple Choice",
          description: "Choisis la bonne réponse. Une seule tentative 🫣"
        )
      case .singleAnswer:
        return ChallengeInfoPopup(
          symbol: "bubble.and.pencil",
          title: "Single Answer",
          description: "Réponse libre. Joue le jeu, sans tricher 👀"
        )
      case .noChoice:
        return ChallengeInfoPopup(
          symbol: "checkmark.circle",
          title: "No Action",
          description: "Rien à faire ici. Valide quand c’est fait ✅"
        )
      }
    }
}

#Preview {
    ChallengeInfoPopup(
        symbol: "photo.artframe",
        title: "Picture challenge",
        description: "Description"
    )
}
