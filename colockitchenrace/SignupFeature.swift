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
        var focusedField: Field?
        var signupUserData = SignupUser()
        var error: Error?

        enum Field: String, Hashable {
            case name
            case surname
            case email
            case password
            case phone
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case goToSigninButtonTapped
        case signupButtonTapped
        case delegate(Delegate)
        case setFocusedField(SignupFeature.State.Field?)
        case signupErrorTrigered(Error)

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
                state.error = nil
                return .run { [signupUserData = state.signupUserData] send in
                    let userDataResult = try await self.authentificationClient.signUp(signupUserData)
                    switch userDataResult {
                    case .success:
                        break
                    case let .failure(error):
                        Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                        await send(.signupErrorTrigered(error))
                    }
                }
            case let .signupErrorTrigered(error):
                state.error = error
                return .none
            }
        }
    }   
}
