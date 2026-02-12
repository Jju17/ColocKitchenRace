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
    @Bindable var store: StoreOf<SignupFeature>
    @FocusState var focusedField: SignupField?
    let nameFieldDelegate = TextFieldDelegate()
    let surnameFieldDelegate = TextFieldDelegate()
    let emailFieldDelegate = TextFieldDelegate()
    let passwordFieldDelegate = TextFieldDelegate()
    let phoneFieldDelegate = TextFieldDelegate()

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Image("logo")
                        .resizable()
                        .frame(width: 150, height: 150, alignment: .center)

                    VStack(spacing: 10) {
                        HStack(spacing: 15) {
                            CKRTextField(title: "NAME*", value: $store.signupUserData.firstName)
                                .textContentType(.givenName)
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
                            CKRTextField(title: "SURNAME*", value: $store.signupUserData.lastName)
                                .textContentType(.familyName)
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
                        CKRTextField(title: "EMAIL*", value: $store.signupUserData.email)
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
                        CKRTextField(title: "PASSWORD*", value: $store.signupUserData.password, isSecure: true)
                            .textContentType(.newPassword)
                            .focused(self.$focusedField, equals: .password)
                            .submitLabel(.next)
                            .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
                                passwordFieldDelegate.shouldReturn = {
                                    self.focusNextField()
                                    return false
                                }

                                textField.delegate = passwordFieldDelegate
                            }
                        CKRTextField(title: "PHONE", value: $store.signupUserData.phone)
                            .textContentType(.telephoneNumber)
                            .focused(self.$focusedField, equals: .phone)
                            .submitLabel(.done)
                        VStack(spacing: 12) {
                            CKRButton("Sign up") {
                                self.store.send(.signupButtonTapped)
                            }
                            .frame(height: 50)

                            HStack {
                                Rectangle().frame(height: 1).foregroundStyle(.gray.opacity(0.3))
                                Text("or").font(.footnote).foregroundStyle(.secondary)
                                Rectangle().frame(height: 1).foregroundStyle(.gray.opacity(0.3))
                            }

                            Button {
                                self.store.send(.googleSignupButtonTapped)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title2)
                                    Text("Sign up with Google")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                self.store.send(.appleSignupButtonTapped)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "apple.logo")
                                        .font(.title2)
                                    Text("Sign up with Apple")
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(.black)
                                )
                            }
                            .buttonStyle(.plain)

                            if let errorMessage = store.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                            HStack {
                                Text("Already have an account?")
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
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Color.ckrSkyLight.ignoresSafeArea() }
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

