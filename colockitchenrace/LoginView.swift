//
//  LoginView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

@Reducer
struct SigninFeature {

    @ObservableState
    struct State {
        var email: String = ""
        var password: String = ""
        var user: User?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case changeToSignupButtonTapped
        case loginButtonTapped
        case userResponse(User)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .changeToSignupButtonTapped:
                return .none
            case let .userResponse(user):
                state.user = user
                return .none
//            case .fetchUser:
//                return .run { send in
//                    guard let uid = Auth.auth().currentUser?.uid,
//                          let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
//                          let user = try? snapshot.data(as: User.self)
//                    else { return }
//                    await send(.fetchUserResult(user))
//                }
            case .loginButtonTapped:
                return .run { [email = state.email, password = state.password] send in
                    do {
                        let result = try await Auth.auth().signIn(withEmail: email, password: password)
                        let firebaseUser: FirebaseAuth.User = result.user
                        let user = colockitchenrace.User(id: UUID(),
                                        uid: firebaseUser.uid,
                                        displayName: firebaseUser.displayName ?? "No name",
                                        email: firebaseUser.email)
                        await send(.userResponse(user))
                    } catch {
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

struct LoginView: View {
    @Perception.Bindable var store: StoreOf<SigninFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                TextField("Email", text: $store.email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("••••••••", text: $store.password)
                    .autocorrectionDisabled()
                Button(
                    action: {
                        store.send(.loginButtonTapped)
                    },
                    label: {
                        Text("Login")
                    }
                )
                HStack {
                    Text("You need an account ?")
                    Button("Click here") {
                        self.store.send(.changeToSignupButtonTapped)
                    }
                }
                .font(.system(size: 14))
            }
        }
    }
}

#Preview {
    LoginView(
        store: Store(initialState: SigninFeature.State()) {
            SigninFeature()
        }
    )
}
