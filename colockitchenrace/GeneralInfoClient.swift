//
//  GeneralInfoClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 17/06/2024.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros

@DependencyClient
struct GeneralInfoClient {
    var getInfos: @Sendable () async throws -> Result<User, Error>
}
