//
//  SingleChoiceView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import SwiftUI

struct SingleChoiceView: View {
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            TextField("Answer", text: $answer)
                .padding(.horizontal)
                .frame(minHeight: 40, maxHeight: 45)
                .background(Color.white)
                .cornerRadius(.defaultRadius)
            Button {
                
            } label: {
                ZStack {
                    Color.blue
                        .cornerRadius(.defaultRadius)
                        .frame(minHeight: 40, maxHeight: 45)
                    Text("Submit")
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.green
        SingleChoiceView(answer: .constant(""))
            .frame(width: .infinity, height: 200, alignment: .center)
            .padding(.horizontal)
    }
    .ignoresSafeArea()
}
