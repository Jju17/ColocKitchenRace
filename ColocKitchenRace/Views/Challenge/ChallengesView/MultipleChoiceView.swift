//
//  MultipleChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct MultipleChoiceView: View {
    @Binding var selectedAnswer: Int?
    let onSubmit: (Data?) -> Void

    var body: some View {
        VStack {
            HStack {
                ForEach(0..<4, id: \.self) { index in
                    Button(action: { selectedAnswer = index }) {
                        Text("Option \(index + 1)")
                            .padding()
                            .background(selectedAnswer == index ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            if selectedAnswer != nil {
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
    }
}
