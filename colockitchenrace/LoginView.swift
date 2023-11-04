//
//  LoginView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

struct LoginFeature: Reducer {
    struct State: Equatable {
        @BindingState var email: String = ""
        @BindingState var password: String = ""
        var user: User?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case loginAuthResult(AuthDataResult)
        case loginButtonTapped
        case loginError(String)
        enum Delegate {
            case userUpdated(User)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(_):
                return .none
            case .delegate(_):
                return .none
            case .loginAuthResult(_):
                return .none
            case .loginButtonTapped:
                return .run { [email = state.email, password = state.password] send in
                    
                }
            case .loginError(_):
                return .none
            }
        }
        .onChange(of: \.user) { oldValue, newValue in
            Reduce { state, action in
                guard let newUser = newValue else { return .none }
                return .send(.delegate(.userUpdated(newUser)))
            }
        }
    }
}

struct LoginView: View {
    let store: StoreOf<LoginFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Form {
                TextField("Email", text: viewStore.$email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                TextField("••••••••", text: viewStore.$password)
                Button(
                    action: {
                        viewStore.send(.loginButtonTapped)
                    },
                    label: {
                        Text("Login")
                    }
                )
            }
        }
    }
}

#Preview {
    LoginView(
        store: Store(initialState: LoginFeature.State()) {
            LoginFeature()
        }
    )
}
