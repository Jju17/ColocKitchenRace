//
//  UserClient.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 27/02/2024.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct UserStore {
    var value: @Sendable () async -> AsyncStream<User> = { AsyncStream(unfolding: { return User(id: UUID()) }) }
    var updateValue: @Sendable (User) async -> Void
}

//extension UserStore {
//    static let live = Self(
//        value: <#T##() async -> AsyncStream<User>#>,
//        updateValue: <#T##(User) async -> Void#>
//    )
//}

//
//struct UserClient: DependencyKey {
//    var get: @Sendable () -> User
//    var set: @Sendable (User) -> Void
//
//    static var liveValue: UserClient {
//        let user = LockIsolated(User(id: UUID()))
//        return UserClient(
//            get: { user.value },
//            set: { user.setValue($0) }
//        )
//    }
//}
//
//func foo() {
//    @Dependency(UserClient.self) var userInfo
//}
