//
//  ProfileCompletionView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 21/02/2026.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ProfileCompletionFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
        var firstName: String = ""
        var lastName: String = ""
        var phoneNumber: String = ""
        var errorMessage: String?
        var isSaving: Bool = false
        var focusedField: ProfileCompletionField?

        init() {
            if let user = userInfo {
                self.firstName = user.firstName
                self.lastName = user.lastName
                self.phoneNumber = user.phoneNumber ?? ""
            }
        }

        /// Test-only initialiser that bypasses @Shared reading.
        init(firstName: String, lastName: String, phoneNumber: String) {
            self.firstName = firstName
            self.lastName = lastName
            self.phoneNumber = phoneNumber
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case _saveSucceeded
        case _saveFailed(String)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case profileCompleted
        }
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .saveButtonTapped:
                state.errorMessage = nil

                let firstName = state.firstName.trimmingCharacters(in: .whitespaces)
                let lastName = state.lastName.trimmingCharacters(in: .whitespaces)
                let phone = state.phoneNumber.trimmingCharacters(in: .whitespaces)

                guard !firstName.isEmpty, !lastName.isEmpty, !phone.isEmpty else {
                    state.errorMessage = "Please fill in all required fields."
                    return .none
                }

                guard UserValidation.isValidPhone(phone) else {
                    state.errorMessage = "Please enter a valid phone number."
                    return .none
                }

                state.isSaving = true

                guard var user = state.userInfo else {
                    state.errorMessage = "No user session found."
                    state.isSaving = false
                    return .none
                }

                user.firstName = firstName
                user.lastName = lastName
                user.phoneNumber = phone
                let updatedUser = user

                return .run { send in
                    try await authenticationClient.updateUser(updatedUser)
                    await send(._saveSucceeded)
                } catch: { error, send in
                    await send(._saveFailed(error.localizedDescription))
                }

            case ._saveSucceeded:
                state.isSaving = false
                return .send(.delegate(.profileCompleted))

            case let ._saveFailed(message):
                state.isSaving = false
                state.errorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

struct ProfileCompletionView: View {
    @Bindable var store: StoreOf<ProfileCompletionFeature>
    @FocusState var focusedField: ProfileCompletionField?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Image("logo")
                        .resizable()
                        .frame(width: 150, height: 150, alignment: .center)

                    Text("Complete your profile")
                        .font(.custom("BaksoSapi", size: 24))
                        .fontWeight(.bold)

                    Text("We need a few more details before you can get started.")
                        .font(.custom("BaksoSapi", size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 10) {
                        CKRTextField(title: "FIRST NAME*", value: $store.firstName,
                                     textContentType: .givenName, autocapitalization: .words, submitLabel: .next)
                            .focused(self.$focusedField, equals: .firstName)
                            .onSubmit { self.focusNextField() }

                        CKRTextField(title: "LAST NAME*", value: $store.lastName,
                                     textContentType: .familyName, autocapitalization: .words, submitLabel: .next)
                            .focused(self.$focusedField, equals: .lastName)
                            .onSubmit { self.focusNextField() }

                        CKRTextField(title: "PHONE*", value: $store.phoneNumber,
                                     textContentType: .telephoneNumber, keyboardType: .phonePad, submitLabel: .done)
                            .focused(self.$focusedField, equals: .phone)

                        VStack(spacing: 12) {
                            CKRButton("Continue") {
                                self.store.send(.saveButtonTapped)
                            }
                            .frame(height: 50)
                            .disabled(store.isSaving)

                            if store.isSaving {
                                ProgressView()
                            }

                            if let errorMessage = store.errorMessage {
                                Text(errorMessage)
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
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Color.ckrMintLight.ignoresSafeArea() }
        }
    }
}

extension ProfileCompletionView {
    private func focusPreviousField() {
        focusedField = focusedField.map {
            ProfileCompletionField(rawValue: $0.rawValue - 1) ?? .phone
        }
    }

    private func focusNextField() {
        focusedField = focusedField.map {
            ProfileCompletionField(rawValue: $0.rawValue + 1) ?? .firstName
        }
    }
}

#Preview {
    ProfileCompletionView(
        store: Store(initialState: ProfileCompletionFeature.State()) {
            ProfileCompletionFeature()
        }
    )
}
