//
//  News.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 16/06/2024.
//

import Foundation
import FirebaseFirestore

struct News: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
    var publicationTimestamp: Timestamp
}

extension News {
    var publicationDate: Date {
        self.publicationTimestamp.dateValue()
    }
}

extension News {
    static var mock: News {
        return News(
            id: UUID().uuidString,
            title: "Title : News of the day",
            body: "Body : Voil",
            publicationTimestamp: .init(seconds: 1720432800, nanoseconds: 0)
        )
    }

    static var mockList: [News] {
        return [
            News(
                id: UUID().uuidString,
                title: "Title1",
                body: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.",
                publicationTimestamp: .init(seconds: 1720432800, nanoseconds: 0)
            ),
            News(
                id: UUID().uuidString,
                title: "Title2",
                body: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.",
                publicationTimestamp: .init(
                    seconds: 1720000800,
                    nanoseconds: 0
                )
            ),
            News(
                id: UUID().uuidString,
                title: "Title3",
                body: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
                publicationTimestamp: .init(
                    seconds: 1719396000,
                    nanoseconds: 0
                )
            ),
            News(
                id: UUID().uuidString,
                title: "Title4",
                body: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged.",
                publicationTimestamp: .init(seconds: 1718791200, nanoseconds: 0)
            )

        ]
    }
}
