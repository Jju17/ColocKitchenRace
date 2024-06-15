//
//  NewsClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 06/06/2024.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros

@DependencyClient
struct NewsClient {
    var startReceiving: @Sendable () async throws -> Result<Bool, Error>
    var stopReceiving: @Sendable () async throws -> Result<Bool, Error>
    var stream: @Sendable () throws -> AsyncStream<[News]>
}

extension NewsClient: DependencyKey {
    static let liveValue = Self(
        startReceiving: {
            return .success(true)
        },
        stopReceiving: {
            return .success(true)
        },
        stream: {
            return AsyncStream { continuation in
                continuation.finish()
            }
        }
    )
}
