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
        case changeToSigninButtonTapped
        case signupButtonTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .changeToSigninButtonTapped:
                return .none
            case .signupButtonTapped:
                return .none
            }
        }
    }
    
}
