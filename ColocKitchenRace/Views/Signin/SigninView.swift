//
//  SigninView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUIIntrospect
import SwiftUI
import os

@Reducer
struct SigninFeature {

    @ObservableState
    struct State {
        var email: String = ""
        var error: Error?
        var focusedField: SigninField?
        var password: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case switchToSignupButtonTapped
        case delegate(Delegate)
        case signinButtonTapped
        case signinErrorTrigered(Error)

        enum Delegate {
            case switchToSignupButtonTapped
        }
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                case .switchToSignupButtonTapped:
                    return .send(.delegate(.switchToSignupButtonTapped))
                case .delegate:
                    return .none
                case .signinButtonTapped:
                    return .run { [state = state] send in
                        let userDataResult = try await self.authentificationClient.signIn(email: state.email, password: state.password)
                        switch userDataResult {
                            case .success:
                                break
                            case let .failure(error):
                                Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                                await send(.signinErrorTrigered(error))
                        }
                    }
                case let .signinErrorTrigered(error):
                    state.error = error
                    return .none
            }
        }
    }
}

struct SigninView: View {
    @Bindable var store: StoreOf<SigninFeature>
    @FocusState var focusedField: SigninField?
    let emailFieldDelegate = TextFieldDelegate()
    let passwordFieldDelegate = TextFieldDelegate()

    var body: some View {
        VStack(spacing: 10) {
            Image("logo")
                .resizable()
                .frame(width: 150, height: 150, alignment: .center)

            VStack(spacing: 10) {
                TextField("", text: $store.email)
                    .textFieldStyle(CKRTextFieldStyle(title: "EMAIL"))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .focused(self.$focusedField, equals: .email)
                    .submitLabel(.next)
                    .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
                        emailFieldDelegate.shouldReturn = {
                            self.focusNextField()
                            return false
                        }

                        textField.delegate = emailFieldDelegate
                    }
                SecureField("", text: $store.password)
                    .textFieldStyle(CKRTextFieldStyle(title: "PASSWORD"))
                    .focused(self.$focusedField, equals: .password)
                    .submitLabel(.done)
                VStack(spacing: 12) {
                    CKRButton("Sign in") {
                        self.store.send(.signinButtonTapped)
                    }
                    .frame(height: 50)
                    if let error = store.error {
                        Text("\(error.localizedDescription)")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    HStack {
                        Text("You need an account ?")
                        Button("Click here") {
                            self.store.send(.switchToSignupButtonTapped)
                        }
                    }
                    .font(.system(size: 14))
                }
                .padding(.top)
            }
            .bind($store.focusedField, to: self.$focusedField)
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button(action: self.focusPreviousField) {
                        Image(systemName: "chevron.up")
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Button(action: self.focusNextField) {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Color.CKRGreen.ignoresSafeArea() }

    }
}

extension SigninView {
    private func focusPreviousField() {
        focusedField = focusedField.map {
            SigninField(rawValue: $0.rawValue - 1) ?? .password
        }
    }

    private func focusNextField() {
        focusedField = focusedField.map {
            SigninField(rawValue: $0.rawValue + 1) ?? .email
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
