//
//  MultipleChoiceView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import SwiftUI

struct MultipleChoiceView: View {
    var choices: MultipleChoiceChallenge

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            HStack(alignment: .center, spacing: 15) {
                Button {

                } label: {
                    ZStack {
                        Color.white
                            .cornerRadius(.defaultRadius)
                        Text(self.choices.choice1)
                    }
                }
                Button {

                } label: {
                    ZStack {
                        Color.white
                            .cornerRadius(.defaultRadius)
                        Text(self.choices.choice2)
                    }
                }
            }
            HStack(alignment: .center, spacing: 15) {
                Button {

                } label: {
                    ZStack {
                        Color.white
                            .cornerRadius(.defaultRadius)
                        Text(self.choices.choice3)
                    }
                }
                Button {

                } label: {
                    ZStack {
                        Color.white
                            .cornerRadius(.defaultRadius)
                        Text(self.choices.choice4)
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.green
        VStack {
            Spacer()
            MultipleChoiceView(choices: .mock)
                .frame(width: .infinity, height: 150)
        }
        .padding()
    }
    .ignoresSafeArea()
}
