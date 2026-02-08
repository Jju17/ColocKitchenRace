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
    struct State: Equatable {
        var focusedField: SignupField?
        var signupUserData = SignupUser()
        var errorMessage: String?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case goToSigninButtonTapped
        case signupButtonTapped
        case delegate(Delegate)
        case signupErrorTriggered(String)

        @CasePathable
        enum Delegate {
            case switchToSigninButtonTapped
        }
    }

    @Dependency(\.authenticationClient) var authenticationClient

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
                state.errorMessage = nil
                return .run { [signupUserData = state.signupUserData] send in
                    _ = try await self.authenticationClient.signUp(signupUserData)
                } catch: { error, send in
                    Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                    await send(.signupErrorTriggered(error.localizedDescription))
                }
            case let .signupErrorTriggered(message):
                state.errorMessage = message
                return .none
            }
        }
    }   
}
