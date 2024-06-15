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
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150, alignment: .center)
                
                VStack(spacing: 10) {
                    HStack(spacing: 15) {
                        CKRTextField(value: $store.signupUserData.firstName) { Text("NAME") }
                        CKRTextField(value: $store.signupUserData.lastName) { Text("SURNAME") }
                    }
                    CKRTextField(value: $store.signupUserData.email) { Text("EMAIL") }
                    SecureField("PASSWORD", text: $store.signupUserData.password)
                    CKRTextField(value: $store.signupUserData.phone) { Text("PHONE") }
                    VStack(spacing: 12) {
                        CKRButton("Sign up") {
                            self.store.send(.signupButtonTapped)
                        }
                        .frame(height: 50)
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

