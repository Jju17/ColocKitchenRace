//
//  NewsClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import ComposableArchitecture
import Dependencies
import FirebaseFirestore

@DependencyClient
struct NewsClient {
    var getLast: @Sendable () async throws -> Result<[News], NewsError>
}

enum NewsError: Error {
    case firebaseError(String)
    case noNewsAvailable
}

extension NewsClient: DependencyKey {
    static let liveValue = Self(
        getLast: {
            do {
                @Shared(.news) var news
                let querySnapshot = try await Firestore.firestore().collection("news")
                    .order(by: "publicationTimestamp", descending: true)
                    .limit(to: 10)
                    .getDocuments()

                let documents = querySnapshot.documents
                let lastNews = documents.compactMap { document in
                    try? document.data(as: News.self)
                }

                await $news.withLock { $0 = lastNews }
                return .success(lastNews)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        }
    )
}

extension DependencyValues {
    var newsClient: NewsClient {
        get { self[NewsClient.self] }
        set { self[NewsClient.self] = newValue }
    }
}
