//
//  NewsCell.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/07/2024.
//

import SwiftUI

struct NewsCell: View {
    let news: News

    var body: some View {
        VStack(alignment: .leading, spacing: nil){
            Text(news.title)
                .font(.headline)
            Text(news.publicationDate.formatted(.dateTime.day().month().year()))
                .font(.caption)
                .foregroundStyle(.gray)
            Text(news.body)
                .font(.subheadline)
        }
    }
}

#Preview {
    List {
        NewsCell(news: .mock)
    }
}
