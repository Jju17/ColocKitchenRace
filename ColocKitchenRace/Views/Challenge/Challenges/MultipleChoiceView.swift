//
//  MultipleChoiceView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import SwiftUI

struct MultipleChoiceView: View {
    var choices: [String]
    var onChoiceSelected: (String) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(choices, id: \.self) { choice in
                Button(action: {
                    onChoiceSelected(choice)
                }) {
                    Text(choice)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .foregroundColor(.black)
                }
            }
        }
        .padding()
    }
}

struct MultipleChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.green.ignoresSafeArea()
            VStack {
                Spacer()
                MultipleChoiceView(choices: ["Choice 1", "Choice 2", "Choice 3", "Choice 4"]) { choice in
                    print("Selected choice: \(choice)")
                }
                .frame(height: 150)
            }
            .padding()
        }
    }
}
