//
//  SignupFeature.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SignupFeature {
    
    @ObservableState
    struct State {
        var name: String = ""
        var surname: String = ""
        var email: String = ""
        var password: String = ""
        var phone: String = ""
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case goToSigninButtonTapped
        case signupButtonTapped
        case delegate(Delegate)

        enum Delegate {
            case switchToSigninButtonTapped
        }
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .goToSigninButtonTapped:
                return .send(.delegate(.switchToSigninButtonTapped))
            case .delegate:
                return .none
            case .signupButtonTapped:
                return .run { _ in
                    try await self.authentificationClient.signIn(email: "julien@gmail.com", password: "jujurahier")
                }
            }
        }
    }
}
