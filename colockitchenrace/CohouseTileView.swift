//
//  CohouseTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 04/11/2023.
//

import SwiftUI

struct CohouseTileView: View {

    let name: String?

    var body: some View {
        ZStack {
            Image("defaultColocBackground")
                .resizable()
                .scaledToFill()
            Rectangle()
                .foregroundColor(.clear)
                .background(
                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom))
            if let name = self.name {
                Text(name)
                    .font(.system(size: 40))
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 150)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

#Preview {
    CohouseTileView(name: nil)
}
