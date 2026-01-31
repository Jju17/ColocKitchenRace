//
//  NewsClient.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

struct News: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
    var publicationTimestamp: Timestamp

    var publicationDate: Date {
        self.publicationTimestamp.dateValue()
    }
}

@DependencyClient
struct NewsClient: Sendable {
    var getAll: @Sendable () async throws -> [News]
    var add: @Sendable (_ title: String, _ body: String) async throws -> News
    var update: @Sendable (_ news: News) async throws -> Void
    var delete: @Sendable (_ newsId: String) async throws -> Void
}

extension NewsClient: DependencyKey {
    static let liveValue = Self(
        getAll: {
            let querySnapshot = try await Firestore.firestore()
                .collection("news")
                .order(by: "publicationTimestamp", descending: true)
                .getDocuments()

            return querySnapshot.documents.compactMap { document in
                try? document.data(as: News.self)
            }
        },
        add: { title, body in
            let newNews = News(
                id: UUID().uuidString,
                title: title,
                body: body,
                publicationTimestamp: Timestamp(date: Date())
            )

            try Firestore.firestore()
                .collection("news")
                .document(newNews.id)
                .setData(from: newNews)

            return newNews
        },
        update: { news in
            try Firestore.firestore()
                .collection("news")
                .document(news.id)
                .setData(from: news)
        },
        delete: { newsId in
            try await Firestore.firestore()
                .collection("news")
                .document(newsId)
                .delete()
        }
    )
}

extension DependencyValues {
    var newsClient: NewsClient {
        get { self[NewsClient.self] }
        set { self[NewsClient.self] = newValue }
    }
}
