//
//  NoChoiceView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import SwiftUI

struct NoChoiceView: View {
    var text: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()
            Text(self.text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ZStack {
        Color.green
        NoChoiceView(text: Challenge.mock.body)
            .padding()
    }
    .ignoresSafeArea()
}
