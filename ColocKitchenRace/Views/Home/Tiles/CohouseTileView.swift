//
//  CohouseTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 04/11/2023.
//

import SwiftUI
import UIKit

struct CohouseTileView: View {

    let name: String?
    var coverImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("defaultColocBackground")
                    .resizable()
                    .scaledToFill()
            }
            Rectangle()
                .foregroundColor(.clear)
                .background(
                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                )
            if let name = self.name {
                Text(name)
                    .font(.custom("BaksoSapi", size: 45))
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
