//
//  NewsClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import ComposableArchitecture
import FirebaseFirestore

// MARK: - Error

enum NewsError: Error {
    case firebaseError(String)
    case noNewsAvailable
}

// MARK: - Client Interface

@DependencyClient
struct NewsClient {
    var getLast: @Sendable () async throws -> Result<[News], NewsError>
    var listenToNews: @Sendable () -> AsyncStream<[News]> = { .never }
}

// MARK: - Implementations

extension NewsClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        getLast: {
            // Demo mode: return mock news without hitting Firestore
            if DemoMode.isActive {
                @Shared(.news) var news
                $news.withLock { $0 = DemoMode.demoNews }
                return .success(DemoMode.demoNews)
            }

            do {
                @Shared(.news) var news

                let snapshot = try await Firestore.firestore()
                    .collection("news")
                    .order(by: "publicationTimestamp", descending: true)
                    .limit(to: 10)
                    .getDocuments()

                let lastNews = snapshot.documents.compactMap { document in
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
                let listener = Firestore.firestore()
                    .collection("news")
                    .order(by: "publicationTimestamp", descending: true)
                    .limit(to: 10)
                    .addSnapshotListener { snapshot, error in
                        // Demo mode: don't overwrite mock news with Firestore data
                        if DemoMode.isActive { return }
                        guard let snapshot, error == nil else { return }

                        let news = snapshot.documents.compactMap { document in
                            try? document.data(as: News.self)
                        }

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

    // MARK: Test

    static let testValue = Self(
        getLast: { .success([]) },
        listenToNews: { .never }
    )

    // MARK: Preview

    static let previewValue: NewsClient = .testValue
}

// MARK: - Registration

extension DependencyValues {
    var newsClient: NewsClient {
        get { self[NewsClient.self] }
        set { self[NewsClient.self] = newValue }
    }
}
