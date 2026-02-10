//
//  ChallengeValidationView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 14/05/2025.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct ChallengeValidationFeature {
    @ObservableState
    struct State {
        var responses: [ChallengeResponse] = []
        var isLoading: Bool = false
        var errorMessage: String?
        var filterStatus: FilterStatus = .all
        var sortOrder: SortOrder = .dateDesc
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case fetchResponses
        case responsesLoaded(Result<[ChallengeResponse], ChallengeResponseError>)
        case setResponseStatus(challengeId: UUID, cohouseId: String, status: ChallengeResponseStatus)
        case setFilterStatus(FilterStatus)
        case setSortOrder(SortOrder)
    }

    enum FilterStatus: String, CaseIterable, Identifiable {
        case all = "All"
        case waiting = "Waiting"
        case processed = "Processed"
        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case dateDesc = "Newest first"
        case dateAsc = "Oldest first"
        case challenge = "By challenge"
        case cohouse = "By cohouse"
        var id: String { rawValue }
    }

    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                case .fetchResponses:
                    state.isLoading = true
                    return .run { send in
                        let result = await self.challengeResponseClient.getAll()
                        await send(.responsesLoaded(result))
                    }
                case .responsesLoaded(.success(let responses)):
                    state.responses = responses
                    state.isLoading = false
                    state.errorMessage = nil
                    return .none
                case .responsesLoaded(.failure(let error)):
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                    return .none
                case let .setResponseStatus(challengeId, cohouseId, status):
                    return .run { [state] send in
                        let result = await self.challengeResponseClient.updateStatus(challengeId, cohouseId, status)
                        switch result {
                            case .success:
                                var updatedResponses = state.responses
                                if let index = updatedResponses.firstIndex(where: { $0.challengeId == challengeId && $0.cohouseId == cohouseId }) {
                                    updatedResponses[index].status = status
                                }
                                await send(.responsesLoaded(.success(updatedResponses)))
                            case .failure(let error):
                                await send(.responsesLoaded(.failure(error)))
                        }
                    }
                case .setFilterStatus(let filterStatus):
                    state.filterStatus = filterStatus
                    return .none
                case .setSortOrder(let sortOrder):
                    state.sortOrder = sortOrder
                    return .none
            }
        }
    }
}

struct ChallengeValidationView: View {
    @Bindable var store: StoreOf<ChallengeValidationFeature>
    @State private var selectedImagePath: IdentifiableString?

    var body: some View {
        NavigationView {
            Group {
                if store.isLoading && store.responses.isEmpty {
                    ProgressView("Loading...")
                } else if let errorMessage = store.errorMessage {
                    Text("Error : \(errorMessage)")
                        .foregroundColor(.red)
                } else if store.responses.isEmpty {
                    ContentUnavailableView(
                        "No responses",
                        systemImage: "checkmark.circle",
                        description: Text("Challenge responses will appear here once submitted")
                    )
                } else {
                    VStack {
                        Picker("Filter responses", selection: $store.filterStatus) {
                            ForEach(ChallengeValidationFeature.FilterStatus.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.palette)
                        .padding(.horizontal)

                        List {
                            ForEach(sortedResponses) { response in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Challenge: \(response.challengeTitle)")
                                            .font(.headline)
                                        Text("Cohouse: \(response.cohouseName)")
                                            .font(.subheadline)
                                        Text("Submitted on: \(response.submissionDate, formatter: dateFormatter)")
                                            .font(.caption)
                                        Text("Status: \(statusLabel(for: response.status))")
                                            .font(.caption)
                                            .foregroundColor(statusColor(for: response.status))
                                        // Display response content
                                        switch response.content {
                                            case .picture(let path):
                                                StorageImage(path: path)
                                                    .onTapGesture {
                                                        selectedImagePath = IdentifiableString(path)
                                                    }
                                            case .multipleChoice(let indices):
                                                Text("Choice: \(indices.map { String($0 + 1) }.joined(separator: ", "))")
                                            case .singleAnswer(let answer):
                                                Text("Response: \(answer)")
                                            case .noChoice:
                                                Text("No specific response")
                                        }
                                    }
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ValidationButton(
                                            label: "Validate",
                                            color: .green,
                                            isActive: response.status == .validated
                                        ) {
                                            store.send(.setResponseStatus(challengeId: response.challengeId, cohouseId: response.cohouseId, status: .validated))
                                        }
                                        .disabled(response.status == .validated)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel("Validate response \(response.id.uuidString)")
                                        ValidationButton(
                                            label: "Invalidate",
                                            color: .red,
                                            isActive: response.status == .invalidated
                                        ) {
                                            store.send(.setResponseStatus(challengeId: response.challengeId, cohouseId: response.cohouseId, status: .invalidated))
                                        }
                                        .disabled(response.status == .invalidated)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel("Invalidate response \(response.id.uuidString)")
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .fullScreenCover(item: $selectedImagePath) { wrapper in
                        FullScreenImageView(imagePath: wrapper.id)
                    }
                }
            }
            .navigationTitle("Challenge responses")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(ChallengeValidationFeature.SortOrder.allCases) { order in
                            Button {
                                store.send(.setSortOrder(order))
                            } label: {
                                if store.sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .accessibilityLabel("Sort responses")
                    }
                }
            }
            .onAppear {
                store.send(.fetchResponses)
            }
        }
    }

    private var sortedResponses: [ChallengeResponse] {
        let filtered: [ChallengeResponse]
        switch store.filterStatus {
        case .all:
            filtered = store.responses
        case .waiting:
            filtered = store.responses.filter { $0.status == .waiting }
        case .processed:
            filtered = store.responses.filter { $0.status == .validated || $0.status == .invalidated }
        }

        switch store.sortOrder {
        case .dateDesc:
            return filtered.sorted { $0.submissionDate > $1.submissionDate }
        case .dateAsc:
            return filtered.sorted { $0.submissionDate < $1.submissionDate }
        case .challenge:
            return filtered.sorted { $0.challengeTitle.localizedCompare($1.challengeTitle) == .orderedAscending }
        case .cohouse:
            return filtered.sorted { $0.cohouseName.localizedCompare($1.cohouseName) == .orderedAscending }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Europe/Paris") // CEST timezone
        return formatter
    }()

    private func statusLabel(for status: ChallengeResponseStatus) -> String {
        switch status {
            case .waiting: return "Waiting"
            case .validated: return "Validated"
            case .invalidated: return "Invalidated"
        }
    }

    private func statusColor(for status: ChallengeResponseStatus) -> Color {
        switch status {
            case .waiting: return .orange
            case .validated: return .green
            case .invalidated: return .red
        }
    }
}

struct IdentifiableString: Identifiable {
    let id: String
    init(_ value: String) { self.id = value }
}

#Preview {
    ChallengeValidationView(
        store: Store(initialState: ChallengeValidationFeature.State(responses: ChallengeResponse.mockList)) {
            ChallengeValidationFeature()
        }
    )
}
