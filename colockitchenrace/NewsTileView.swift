//
//  NewsTileView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/07/2024.
//

import ComposableArchitecture
import SwiftUI

struct NewsTileView: View {

    var allNews: [News]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.CKRBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("News")
                            .font(.system(size: 26))
                            .fontWeight(.heavy)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding(.top)

                List {
                    ForEach(self.allNews) { news in
                        NewsCell(news: news)
                    }
                }
                .listStyle(.inset)
                .cornerRadius(15)
                .padding()
            }
        }
        .frame(height: 230)
    }
}
#Preview {
    NewsTileView(allNews: News.mockList)
}
