//
//  SignupView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import ComposableArchitecture
import SwiftUIIntrospect
import SwiftUI

struct SignupView: View {
    @Perception.Bindable var store: StoreOf<SignupFeature>
    @FocusState var focusedField: SignupField?
    let nameFieldDelegate = TextFieldDelegate()
    let surnameFieldDelegate = TextFieldDelegate()
    let emailFieldDelegate = TextFieldDelegate()
    let passwordFieldDelegate = TextFieldDelegate()
    let phoneFieldDelegate = TextFieldDelegate()

    var body: some View {
        WithPerceptionTracking {

            VStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150, alignment: .center)

                VStack(spacing: 10) {
                    HStack(spacing: 15) {
                        TextField("", text: $store.signupUserData.firstName)
                            .textFieldStyle(CKRTextFieldStyle(title: "NAME"))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused(self.$focusedField, equals: .name)
                            .submitLabel(.next)
                            .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
                                nameFieldDelegate.shouldReturn = {
                                    self.focusNextField()
                                    return false
                                }

                                textField.delegate = nameFieldDelegate
                            }
                            .onSubmit { self.focusNextField() }
                        TextField("", text: $store.signupUserData.lastName)
                            .textFieldStyle(CKRTextFieldStyle(title: "SURNAME"))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused(self.$focusedField, equals: .surname)
                            .submitLabel(.next)
                            .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
                                surnameFieldDelegate.shouldReturn = {
                                    self.focusNextField()
                                    return false
                                }

                                textField.delegate = surnameFieldDelegate
                            }
                    }
                    TextField("", text: $store.signupUserData.email)
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
                    SecureField("", text: $store.signupUserData.password)
                        .textFieldStyle(CKRTextFieldStyle(title: "PASSWORD"))
                        .focused(self.$focusedField, equals: .password)
                        .submitLabel(.next)
                        .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
                            passwordFieldDelegate.shouldReturn = {
                                self.focusNextField()
                                return false
                            }

                            textField.delegate = passwordFieldDelegate
                        }
                    TextField("", text: $store.signupUserData.phone)
                        .textFieldStyle(CKRTextFieldStyle(title: "PHONE"))
                        .textContentType(.telephoneNumber)
                        .focused(self.$focusedField, equals: .phone)
                        .submitLabel(.done)
                    VStack(spacing: 12) {
                        CKRButton("Sign up") {
                            self.store.send(.signupButtonTapped)
                        }
                        .frame(height: 50)
                        if let error = store.error {
                            Text("\(error.localizedDescription)")
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                        HStack {
                            Text("Already have an account ?")
                            Button("Click here") {
                                self.store.send(.goToSigninButtonTapped)
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
            .background { Color.CKRBlue.ignoresSafeArea() }
        }
    }
}

extension SignupView {
    private func focusPreviousField() {
        focusedField = focusedField.map {
            SignupField(rawValue: $0.rawValue - 1) ?? .phone
        }
    }

    private func focusNextField() {
        focusedField = focusedField.map {
            SignupField(rawValue: $0.rawValue + 1) ?? .name
        }
    }
}

#Preview {
    SignupView(store: Store(initialState: SignupFeature.State()) {
        SignupFeature()
        }
    )
}

