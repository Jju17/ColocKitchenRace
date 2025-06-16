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

#Preview {
    ChallengeInfoPopup(
        symbol: "photo.artframe",
        title: "Picture challenge",
        description: "Description"
    )
}
