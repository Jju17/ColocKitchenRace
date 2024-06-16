//
//  SignupView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/03/2024.
//

import ComposableArchitecture
import SwiftUI

struct SignupView: View {
    @Perception.Bindable var store: StoreOf<SignupFeature>
    @FocusState var focusedField: SignupFeature.State.Field?

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
                            .onSubmit { store.send(.setFocusedField(.surname)) }
                        TextField("", text: $store.signupUserData.lastName)
                            .textFieldStyle(CKRTextFieldStyle(title: "SURNAME"))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused(self.$focusedField, equals: .surname)
                            .submitLabel(.next)
                            .onSubmit { store.send(.setFocusedField(.email)) }
                    }
                    TextField("", text: $store.signupUserData.email)
                        .textFieldStyle(CKRTextFieldStyle(title: "EMAIL"))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .focused(self.$focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { store.send(.setFocusedField(.password)) }
                    SecureField("", text: $store.signupUserData.password)
                        .textFieldStyle(CKRTextFieldStyle(title: "PASSWORD"))
                        .focused(self.$focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { store.send(.setFocusedField(.phone)) }
                    TextField("", text: $store.signupUserData.phone)
                        .textFieldStyle(CKRTextFieldStyle(title: "PHONE"))
                        .textContentType(.telephoneNumber)
                        .focused(self.$focusedField, equals: .phone)
                        .submitLabel(.done)
                        .onSubmit { store.send(.setFocusedField(nil)) }
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Color.CKRBlue.ignoresSafeArea() }
        }
    }
}

#Preview {
    SignupView(store: Store(initialState: SignupFeature.State()) {
        SignupFeature()
        }
    )
}

