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

        // Cohouse picker
        var cohouses: [CohouseListItem] = []
        var isLoadingCohouses: Bool = false
        var selectedCohouseId: String?

        // History
        var history: [NotificationHistoryItem] = []
        var isLoadingHistory: Bool = false
    }

    enum NotificationTarget: String, CaseIterable, Equatable {
        case all = "All users"
        case cohouse = "A cohouse"
        case edition = "An edition"
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case cohousesLoaded([CohouseListItem])
        case cohousesLoadFailed
        case historyLoaded([NotificationHistoryItem])
        case historyLoadFailed
        case sendNotificationButtonTapped
        case notificationSent(NotificationResult)
        case notificationFailed(String)
        case clearResult
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedTarget):
                // Reset cohouse selection when switching targets
                if state.selectedTarget != .cohouse {
                    state.selectedCohouseId = nil
                }
                return .none

            case .binding:
                return .none

            case .onAppear:
                var effects: [Effect<Action>] = []

                if state.cohouses.isEmpty {
                    state.isLoadingCohouses = true
                    effects.append(.run { send in
                        let result = await cohouseClient.getAllCohouses()
                        switch result {
                        case let .success(cohouses):
                            await send(.cohousesLoaded(cohouses))
                        case .failure:
                            await send(.cohousesLoadFailed)
                        }
                    })
                }

                state.isLoadingHistory = true
                effects.append(.run { send in
                    do {
                        let items = try await notificationClient.getHistory()
                        await send(.historyLoaded(items))
                    } catch {
                        await send(.historyLoadFailed)
                    }
                })

                return .merge(effects)

            case let .cohousesLoaded(cohouses):
                state.cohouses = cohouses
                state.isLoadingCohouses = false
                return .none

            case .cohousesLoadFailed:
                state.isLoadingCohouses = false
                return .none

            case let .historyLoaded(items):
                state.history = items
                state.isLoadingHistory = false
                return .none

            case .historyLoadFailed:
                state.isLoadingHistory = false
                return .none

            case .sendNotificationButtonTapped:
                guard !state.title.isEmpty, !state.body.isEmpty else {
                    state.resultMessage = "Title and message are required"
                    state.isSuccess = false
                    return .none
                }

                if state.selectedTarget == .cohouse && state.selectedCohouseId == nil {
                    state.resultMessage = "Please select a cohouse"
                    state.isSuccess = false
                    return .none
                }

                if state.selectedTarget == .edition && state.targetId.isEmpty {
                    state.resultMessage = "Edition ID is required"
                    state.isSuccess = false
                    return .none
                }

                state.isLoading = true
                state.resultMessage = nil

                let title = state.title
                let body = state.body
                let target = state.selectedTarget
                let cohouseId = state.selectedCohouseId
                let targetId = state.targetId

                return .run { send in
                    do {
                        let result: NotificationResult
                        switch target {
                        case .all:
                            result = try await notificationClient.sendToAll(title, body)
                        case .cohouse:
                            result = try await notificationClient.sendToCohouse(cohouseId ?? "", title, body)
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
                        state.resultMessage = "Notification sent to \(sent) user(s)"
                    } else {
                        state.resultMessage = "Notification sent successfully"
                    }
                    // Clear form on success
                    state.title = ""
                    state.body = ""
                    state.targetId = ""
                    state.selectedCohouseId = nil
                } else {
                    state.resultMessage = "Failed to send: \(result.message ?? "Unknown error")"
                }

                // Refresh history after send
                return .run { send in
                    do {
                        let items = try await notificationClient.getHistory()
                        await send(.historyLoaded(items))
                    } catch {
                        await send(.historyLoadFailed)
                    }
                }

            case let .notificationFailed(error):
                state.isLoading = false
                state.isSuccess = false
                state.resultMessage = "Error: \(error)"
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
    @State private var selectedHistoryItem: NotificationHistoryItem?

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
                        if store.isLoadingCohouses {
                            HStack {
                                ProgressView()
                                Text("Loading cohouses…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if store.cohouses.isEmpty {
                            Text("No cohouses found")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Cohouse", selection: $store.selectedCohouseId) {
                                Text("Select a cohouse")
                                    .tag(nil as String?)
                                ForEach(store.cohouses) { cohouse in
                                    Text(cohouse.name)
                                        .tag(cohouse.id as String?)
                                }
                            }
                        }
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
                    .disabled(
                        store.isLoading
                        || store.title.isEmpty
                        || store.body.isEmpty
                        || (store.selectedTarget == .cohouse && store.selectedCohouseId == nil)
                        || (store.selectedTarget == .edition && store.targetId.isEmpty)
                    )
                }

                if let resultMessage = store.resultMessage {
                    Section(header: Text("Result")) {
                        Label(
                            resultMessage,
                            systemImage: store.isSuccess == true ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(store.isSuccess == true ? .green : .red)
                    }
                }

                // History
                Section(header: Text("History")) {
                    if store.isLoadingHistory && store.history.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Loading history…")
                                .foregroundStyle(.secondary)
                        }
                    } else if store.history.isEmpty {
                        Text("No notifications sent yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.history) { item in
                            Button {
                                selectedHistoryItem = item
                            } label: {
                                historyRow(item)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .onAppear { store.send(.onAppear) }
            .sheet(item: $selectedHistoryItem) { item in
                notificationDetailView(item)
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ item: NotificationHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                targetBadge(item.target)
                Spacer()
                if let sentAt = item.sentAt {
                    Text(sentAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(item.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if item.target != "all" {
                HStack(spacing: 12) {
                    Label("\(item.sent) sent", systemImage: "arrow.up.circle")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    if item.failed > 0 {
                        Label("\(item.failed) failed", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func notificationDetailView(_ item: NotificationHistoryItem) -> some View {
        NavigationStack {
            Form {
                Section(header: Text("Status")) {
                    HStack {
                        Text("Target")
                        Spacer()
                        targetBadge(item.target)
                    }

                    if let targetId = item.targetId {
                        HStack {
                            Text("Target ID")
                            Spacer()
                            Text(targetId)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }

                    if let sentAt = item.sentAt {
                        HStack {
                            Text("Sent at")
                            Spacer()
                            Text(sentAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if item.target != "all" {
                        HStack {
                            Text("Sent")
                            Spacer()
                            Text("\(item.sent)")
                                .foregroundStyle(item.sent > 0 ? .green : .secondary)
                        }

                        HStack {
                            Text("Failed")
                            Spacer()
                            Text("\(item.failed)")
                                .foregroundStyle(item.failed > 0 ? .red : .secondary)
                        }
                    }
                }

                Section(header: Text("Content")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = item.message {
                    Section(header: Text("Error")) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Notification detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        selectedHistoryItem = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func targetBadge(_ target: String) -> some View {
        let (label, color): (String, Color) = switch target {
        case "all": ("All users", .blue)
        case "cohouse": ("Cohouse", .orange)
        case "edition": ("Edition", .purple)
        default: (target, .gray)
        }

        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    NotificationView(
        store: Store(initialState: NotificationFeature.State()) {
            NotificationFeature()
        }
    )
}
