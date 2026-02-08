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
        case setFocusedField(SignupField?)
        case signupErrorTrigered(String)

        @CasePathable
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
            case let .setFocusedField(newFocus):
                state.focusedField = newFocus
                return .none
            case .signupButtonTapped:
                state.errorMessage = nil
                return .run { [signupUserData = state.signupUserData] send in
                    _ = try await self.authentificationClient.signUp(signupUserData)
                } catch: { error, send in
                    Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                    await send(.signupErrorTrigered(error.localizedDescription))
                }
            case let .signupErrorTrigered(message):
                state.errorMessage = message
                return .none
            }
        }
    }   
}
