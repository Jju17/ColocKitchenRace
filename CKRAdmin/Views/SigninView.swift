//
//  SigninView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
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
        case signinButtonTapped
        case signinErrorTrigered(Error)
    }

    @Dependency(\.authentificationClient) var authentificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .signinButtonTapped:
                return .run { [state] send in
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
            Image("AdminLogo")
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
        .background { Color.CKRPurple.ignoresSafeArea() }
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
