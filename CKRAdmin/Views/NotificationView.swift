//
//  NotificationView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NotificationFeature {

    @ObservableState
    struct State: Equatable {
        var title: String = ""
        var body: String = ""
        var selectedTarget: NotificationTarget = .all
        var targetId: String = ""
        var isLoading: Bool = false
        var resultMessage: String?
        var isSuccess: Bool?
    }

    enum NotificationTarget: String, CaseIterable, Equatable {
        case all = "All users"
        case cohouse = "A cohouse"
        case edition = "An edition"
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case sendNotificationButtonTapped
        case notificationSent(NotificationResult)
        case notificationFailed(String)
        case clearResult
    }

    @Dependency(\.notificationClient) var notificationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .sendNotificationButtonTapped:
                guard !state.title.isEmpty, !state.body.isEmpty else {
                    state.resultMessage = "Title and message are required"
                    state.isSuccess = false
                    return .none
                }

                if state.selectedTarget != .all && state.targetId.isEmpty {
                    state.resultMessage = "ID is required"
                    state.isSuccess = false
                    return .none
                }

                state.isLoading = true
                state.resultMessage = nil

                let title = state.title
                let body = state.body
                let target = state.selectedTarget
                let targetId = state.targetId

                return .run { send in
                    do {
                        let result: NotificationResult
                        switch target {
                        case .all:
                            result = try await notificationClient.sendToAll(title, body)
                        case .cohouse:
                            result = try await notificationClient.sendToCohouse(targetId, title, body)
                        case .edition:
                            result = try await notificationClient.sendToEdition(targetId, title, body)
                        }
                        await send(.notificationSent(result))
                    } catch {
                        await send(.notificationFailed(error.localizedDescription))
                    }
                }

            case let .notificationSent(result):
                state.isLoading = false
                state.isSuccess = result.success

                if result.success {
                    if let sent = result.sent {
                        state.resultMessage = "✅ Notification sent to \(sent) user(s)"
                    } else {
                        state.resultMessage = "✅ Notification sent successfully"
                    }
                    // Clear form on success
                    state.title = ""
                    state.body = ""
                    state.targetId = ""
                } else {
                    state.resultMessage = "❌ Failed to send: \(result.message ?? "Unknown error")"
                }
                return .none

            case let .notificationFailed(error):
                state.isLoading = false
                state.isSuccess = false
                state.resultMessage = "❌ Error: \(error)"
                return .none

            case .clearResult:
                state.resultMessage = nil
                state.isSuccess = nil
                return .none
            }
        }
    }
}

struct NotificationView: View {
    @Bindable var store: StoreOf<NotificationFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Target")) {
                    Picker("Send to", selection: $store.selectedTarget) {
                        ForEach(NotificationFeature.NotificationTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)

                    if store.selectedTarget == .cohouse {
                        TextField("Cohouse ID", text: $store.targetId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else if store.selectedTarget == .edition {
                        TextField("Edition ID", text: $store.targetId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section(header: Text("Content")) {
                    TextField("Title", text: $store.title)
                    TextField("Message", text: $store.body, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        store.send(.sendNotificationButtonTapped)
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Send notification")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(store.isLoading || store.title.isEmpty || store.body.isEmpty)
                }

                if let resultMessage = store.resultMessage {
                    Section(header: Text("Result")) {
                        Text(resultMessage)
                            .foregroundColor(store.isSuccess == true ? .green : .red)
                    }
                }
            }
            .navigationTitle("Notifications")
        }
    }
}

#Preview {
    NotificationView(
        store: Store(initialState: NotificationFeature.State()) {
            NotificationFeature()
        }
    )
}
