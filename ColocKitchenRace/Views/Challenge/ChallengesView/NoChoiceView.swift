//
//  NoChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct NoChoiceView: View {
    let onSubmit: (Data?) -> Void

    var body: some View {
        Button("SUBMIT") {
            onSubmit(nil)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
