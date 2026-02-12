//
//  EmailVerificationView.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 12/02/2026.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Feature

@Reducer
struct EmailVerificationFeature {

    @ObservableState
    struct State: Equatable {
        var isChecking = false
        var isResending = false
        var message: String?
    }

    enum Action {
        case checkVerificationTapped
        case resendEmailTapped
        case signOutTapped
        case delegate(Delegate)
        case _checkResult(Bool)
        case _resendSucceeded
        case _resendFailed

        enum Delegate {
            case emailVerified
        }
    }

    @Dependency(\.authenticationClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkVerificationTapped:
                state.isChecking = true
                state.message = nil
                return .run { send in
                    let verified = try await authClient.reloadCurrentUser()
                    await send(._checkResult(verified))
                } catch: { _, send in
                    await send(._checkResult(false))
                }

            case let ._checkResult(verified):
                state.isChecking = false
                if verified {
                    // Notify AppFeature to switch to main tab.
                    // Firebase's addStateDidChangeListener does NOT fire
                    // after user.reload(), so we use a delegate action instead.
                    return .send(.delegate(.emailVerified))
                } else {
                    state.message = "Email not yet verified. Check your inbox."
                    return .none
                }

            case .resendEmailTapped:
                state.isResending = true
                state.message = nil
                return .run { send in
                    try await authClient.resendVerificationEmail()
                    await send(._resendSucceeded)
                } catch: { _, send in
                    await send(._resendFailed)
                }

            case ._resendSucceeded:
                state.isResending = false
                state.message = "Verification email sent! Check your inbox."
                return .none

            case ._resendFailed:
                state.isResending = false
                state.message = "Failed to send email. Try again."
                return .none

            case .signOutTapped:
                return .run { _ in
                    try await authClient.signOut()
                }
            }
        }
    }
}

// MARK: - View

struct EmailVerificationView: View {
    let store: StoreOf<EmailVerificationFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge")
                .font(.system(size: 72))
                .foregroundStyle(.ckrLavender)

            // Title
            Text("Verify your email")
                .font(.custom("BaksoSapi", size: 28))
                .fontWeight(.bold)

            // Description
            Text("A verification link has been sent to your email address. Please check your inbox and click the link to continue.")
                .font(.custom("BaksoSapi", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Feedback message
            if let message = store.message {
                Text(message)
                    .font(.custom("BaksoSapi", size: 14))
                    .foregroundStyle(message.contains("sent") ? .ckrMint : .orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Primary button — I've verified
            Button {
                store.send(.checkVerificationTapped)
            } label: {
                HStack {
                    if store.isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text("I've verified my email")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ckrLavender)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isChecking)
            .padding(.horizontal, 32)

            // Secondary button — Resend
            Button {
                store.send(.resendEmailTapped)
            } label: {
                HStack {
                    if store.isResending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .ckrLavender))
                            .scaleEffect(0.8)
                    }
                    Text("Resend verification email")
                }
                .font(.custom("BaksoSapi", size: 16))
                .foregroundStyle(.ckrLavender)
            }
            .disabled(store.isResending)

            Spacer()

            // Sign out link
            Button {
                store.send(.signOutTapped)
            } label: {
                Text("Sign out")
                    .font(.custom("BaksoSapi", size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    EmailVerificationView(
        store: Store(initialState: EmailVerificationFeature.State()) {
            EmailVerificationFeature()
        }
    )
}
