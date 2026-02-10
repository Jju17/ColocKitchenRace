//
//  SigninView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 19/10/2023.
//

import ComposableArchitecture
import SwiftUI
import SwiftUIIntrospect
import os

@Reducer
struct SigninFeature {

    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var errorMessage: String?
        var focusedField: SigninField?
        var password: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case switchToSignupButtonTapped
        case delegate(Delegate)
        case signinButtonTapped
        case signinErrorTriggered(String)

        @CasePathable
        enum Delegate {
            case switchToSignupButtonTapped
        }
    }

    @Dependency(\.authenticationClient) var authenticationClient

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
                    guard !state.email.trimmingCharacters(in: .whitespaces).isEmpty,
                          !state.password.isEmpty
                    else {
                        state.errorMessage = "Please fill in all fields."
                        return .none
                    }
                    return .run { [state] send in
                        _ = try await self.authenticationClient.signIn(email: state.email, password: state.password)
                    } catch: { error, send in
                        Logger.authLog.log(level: .fault, "\(error.localizedDescription)")
                        await send(.signinErrorTriggered(error.localizedDescription))
                    }
                case let .signinErrorTriggered(message):
                    state.errorMessage = message
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
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Image("logo")
                        .resizable()
                        .frame(width: 150, height: 150, alignment: .center)

                    VStack(spacing: 10) {
                        CKRTextField(title: "EMAIL", value: $store.email)
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
                        CKRTextField(title: "PASSWORD", value: $store.password, isSecure: true)
                            .textContentType(.password)
                            .focused(self.$focusedField, equals: .password)
                            .submitLabel(.done)
                        VStack(spacing: 12) {
                            CKRButton("Sign in") {
                                self.store.send(.signinButtonTapped)
                            }
                            .frame(height: 50)
                            if let errorMessage = store.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                            HStack {
                                Text("You need an account?")
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
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Color.CKRGreen.ignoresSafeArea() }
        }
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
