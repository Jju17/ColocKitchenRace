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
                let data = state.signupUserData
                if let error = UserValidation.validateProfileFields(
                    firstName: data.firstName,
                    lastName: data.lastName,
                    email: data.email
                ) {
                    state.errorMessage = error
                    return .none
                }
                guard !data.password.isEmpty else {
                    state.errorMessage = "Please fill in all required fields."
                    return .none
                }
                return .run { send in
                    _ = try await self.authenticationClient.signUp(data)
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
