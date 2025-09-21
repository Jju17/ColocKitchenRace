//
//  MultipleChoiceView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 22/05/2025.
//

import SwiftUI

struct MultipleChoiceView: View {
    let choices: [String]
    @Binding var selectedIndex: Int?
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(choices.enumerated()), id: \.offset) { idx, title in
                Button {
                    selectedIndex = idx
                } label: {
                    HStack { Text(title).frame(maxWidth: .infinity, alignment: .leading) }
                        .padding()
                        .background(selectedIndex == idx ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            if selectedIndex != nil {
                Button("SUBMIT", action: onSubmit)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}
