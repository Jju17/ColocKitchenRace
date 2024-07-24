//
//  PictureChoiceView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/07/2024.
//

import SwiftUI

struct PictureChoiceView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            ZStack {
                Color.white
                    .cornerRadius(.defaultRadius)
                Image(systemName: "photo.badge.plus")
                    .imageScale(.large)
            }
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
        PictureChoiceView()
            .frame(width: .infinity, height: 150)
            .padding()
    }
    .ignoresSafeArea()
}
