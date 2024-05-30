//
//  SigninView.swift
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
        case signinButtonTapped
        case userResponse(User)
    }

    @Dependency(\.authentificationClient) var authentificationClient

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
            case .signinButtonTapped:
                return .run { _ in
                    try await self.authentificationClient.signIn(email: "julien@gmail.com", password: "jujurahier")
                }
            }
        }
    }
}

struct SigninView: View {
    @Perception.Bindable var store: StoreOf<SigninFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150, alignment: .center)

                VStack(spacing: 10) {
                    CKRTextField(value: $store.email) {
                        Text("EMAIL")
                    }
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    CKRTextField(value: $store.password) {
                        Text("PASSWORD")
                    }
                    VStack(spacing: 12) {
                        CKRButton("Sign in") {
                            self.store.send(.signinButtonTapped)
                        }
                        .frame(height: 50)
                        HStack {
                            Text("You need an account ?")
                            Button("Click here") {
                                self.store.send(.changeToSignupButtonTapped)
                            }
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top)
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Color.CKRGreen.ignoresSafeArea() }
        }
    }
}

#Preview {
    SigninView(
        store: Store(initialState: SigninFeature.State()) {
            SigninFeature()
        }
    )
}
