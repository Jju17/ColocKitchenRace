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
    var listenToNews: @Sendable () -> AsyncStream<[News]> = { .never }
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

                $news.withLock { $0 = lastNews }
                return .success(lastNews)
            } catch {
                return .failure(.firebaseError(error.localizedDescription))
            }
        },
        listenToNews: {
            AsyncStream { continuation in
                let listener = Firestore.firestore().collection("news")
                    .order(by: "publicationTimestamp", descending: true)
                    .limit(to: 10)
                    .addSnapshotListener { snapshot, error in
                        guard let snapshot, error == nil else { return }

                        let news = snapshot.documents.compactMap { document in
                            try? document.data(as: News.self)
                        }

                        // Update shared state
                        @Shared(.news) var sharedNews
                        $sharedNews.withLock { $0 = news }

                        continuation.yield(news)
                    }

                continuation.onTermination = { _ in
                    listener.remove()
                }
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
