//
//  SingleAnswerView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct SingleAnswerView: View {
    @State private var answer: String = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack {
            TextField("Enter answer", text: $answer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("SUBMIT") {
                onSubmit(answer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
