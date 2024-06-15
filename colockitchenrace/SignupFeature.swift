//
//  SignupFeature.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct SignupFeature {
    
    @ObservableState
    struct State {
        var signupUserData = SignupUser()
        @Shared(.userInfo) var userInfo
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
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .goToSigninButtonTapped:
                return .send(.delegate(.switchToSigninButtonTapped))
            case .delegate:
                return .none
            case .signupButtonTapped:
                return .run { [signupUserData = state.signupUserData] send in
                    let userDataResult = try await self.authentificationClient.signUp(signupUserData)
                    switch userDataResult {
                    case let .success(newUserData):
                        @Shared(.userInfo) var userInfo
                        userInfo = newUserData
                    case let .failure(error):
                        Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                        break
                    }
                }
            }
        }
    }
}
