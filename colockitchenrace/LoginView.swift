//
//  LoginView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftUI

@Reducer
struct LoginFeature {

    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case loginButtonTapped
        enum Delegate: Equatable {
            case userSessionUpdated(FirebaseAuth.User)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .delegate:
                return .none
//            case .fetchUser:
//                return .run { send in
//                    guard let uid = Auth.auth().currentUser?.uid,
//                          let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
//                          let user = try? snapshot.data(as: User.self)
//                    else { return }
//                    await send(.fetchUserResult(user))
//                }
//            case let .fetchUserResult(result):
//                state.currentUser = result
//                return .none
//            case let .loginAuthResult(result):
//                state.userSession = result.user
//                return .run { send in
//                    await send(.fetchUser)
//                }
            case .loginButtonTapped:
                return .run { [email = state.email, password = state.password] send in
                    do {
                        let result = try await Auth.auth().signIn(withEmail: email, password: password)
                        await send(.delegate(.userSessionUpdated(result.user)))
                    } catch {
                        fatalError()
                    }
                }
            }
        }
//        .onChange(of: \.currentUser) { oldValue, newValue in
//            Reduce { state, action in
//                guard let newUser = newValue else { return .none }
//                return .send(.delegate(.userUpdated(newUser)))
//            }
//        }
    }
}

struct LoginView: View {
    @Perception.Bindable var store: StoreOf<LoginFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                TextField("Email", text: $store.email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                TextField("••••••••", text: $store.password)
                Button(
                    action: {
                        store.send(.loginButtonTapped)
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
