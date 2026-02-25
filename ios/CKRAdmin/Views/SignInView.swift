//
//  SignInView.swift
//  AdminCKR
//
//  Created by Julien Rahier on 3/15/25.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI
import os

@Reducer
struct SignInFeature {

    @ObservableState
    struct State {
        var email: String = ""
        var error: Error?
        var focusedField: SignInField?
        var password: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case signinButtonTapped
        case signinErrorTriggered(Error)
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .signinButtonTapped:
                return .run { [state] send in
                    _ = try await self.authenticationClient.signIn(email: state.email, password: state.password)
                } catch: { error, send in
                    Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                    await send(.signinErrorTriggered(error))
                }
            case let .signinErrorTriggered(error):
                state.error = error
                return .none
            }
        }
    }
}

struct SignInView: View {
    @Bindable var store: StoreOf<SignInFeature>
    @FocusState var focusedField: SignInField?

    var body: some View {
        VStack(spacing: 10) {
            Image("AdminLogoNoFill")
                .resizable()
                .frame(width: 180, height: 180, alignment: .center)

            VStack(spacing: 10) {
                CKRTextField(title: "EMAIL", value: $store.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .focused(self.$focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { self.focusNextField() }
                CKRTextField(title: "PASSWORD", value: $store.password, isSecure: true)
                    .textContentType(.password)
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
        .background { Color.ckrLavenderLight.ignoresSafeArea() }
    }
}

extension SignInView {
    private func focusPreviousField() {
        focusedField = focusedField.map {
            SignInField(rawValue: $0.rawValue - 1) ?? .password
        }
    }

    private func focusNextField() {
        focusedField = focusedField.map {
            SignInField(rawValue: $0.rawValue + 1) ?? .email
        }
    }
}

#Preview {
    SignInView(
        store: Store(initialState: SignInFeature.State()) {
            SignInFeature()
        }
    )
}
